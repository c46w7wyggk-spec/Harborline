--!strict
-- Runs at most one job per player. The server samples the player's position at 10 Hz and feeds
-- it to the job's state machine; the client only ever *asks* to start or cancel.
--
-- Payout safety:
--  * The job is removed from `active` before any reward is applied, so it can only pay once.
--  * Leaving, dying or cancelling voids the job (no cash) and applies the abandon cooldown.
--  * Successful runs faster than the job's physical minimum, or with teleport-like movement,
--    pay nothing and add a flag. Repeated flags kick the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JobsConfig = require(ReplicatedStorage.Shared.Config.Jobs)
local Layout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local VehicleService = require(script.Parent.VehicleService)
local TutorialService = require(script.Parent.TutorialService)
local Net = require(script.Parent.Net)

local JobModules = {
	courier = require(script.Parent.Parent.Jobs.Courier),
	race = require(script.Parent.Parent.Jobs.Race),
	heist = require(script.Parent.Parent.Jobs.Heist),
}

local TICK = 0.1
local OBJECTIVE_PUSH_EVERY = 0.25

type Run = {
	job: any,
	jobId: string,
	startedAt: number,
	startPos: { x: number, z: number },
	lastPos: { x: number, z: number }?,
	lastT: number,
	lootBag: BasePart?,
}

local JobService = {}
local active: { [Player]: Run } = {}
local flags: { [Player]: number } = {}
local rng = Random.new()

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?, char:FindFirstChildOfClass("Humanoid")
end

local function flatPos(part: BasePart): { x: number, z: number }
	return { x = part.Position.X, z = part.Position.Z }
end

function JobService.flag(player: Player, why: string)
	flags[player] = (flags[player] or 0) + 1
	warn(string.format("[Anticheat] user=%d flag %d: %s", player.UserId, flags[player], why))
	if flags[player] >= JobsConfig.FlagsBeforeKick then
		player:Kick("Harborline detected unusual movement. If this was a mistake, just rejoin.")
	end
end

local function setLootBag(player: Player, run: Run, on: boolean)
	if on and not run.lootBag then
		local root = rootOf(player)
		if not root then
			return
		end
		local bag = Instance.new("Part")
		bag.Name = "LootBag"
		bag.Size = Vector3.new(2.2, 2.2, 1.4)
		bag.Color = Color3.fromRGB(70, 160, 90)
		bag.Material = Enum.Material.Fabric
		bag.CanCollide = false
		bag.Massless = true
		bag.CFrame = root.CFrame * CFrame.new(0, 0.4, 1.3)
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = bag
		w.Parent = bag
		bag.Parent = root.Parent
		run.lootBag = bag
	elseif not on and run.lootBag then
		run.lootBag:Destroy()
		run.lootBag = nil
	end
end

local function sendObjective(player: Player, run: Run)
	local obj = run.job:objective(os.clock())
	Net.Job:FireClient(player, {
		kind = "objective",
		jobId = run.jobId,
		name = JobsConfig.Jobs[run.jobId].name,
		objective = obj,
	})
end

-- Ends a run exactly once. `result` comes from the job state machine (or a synthetic failure).
local function finish(player: Player, result: any)
	local run = active[player]
	if not run then
		return
	end
	active[player] = nil -- single exit point: nothing below can run twice for this job
	setLootBag(player, run, false)

	local p = DataService.profile(player)
	if not p then
		return
	end
	local nowClock = os.clock()

	if result.success then
		local elapsed = if run.jobId == "race" then run.job:timedSeconds(nowClock) else nowClock - run.startedAt
		local floor = run.job:minimumSeconds(run.startPos)
		if elapsed < floor then
			JobService.flag(player, string.format("%s finished in %.1fs (floor %.1fs)", run.jobId, elapsed, floor))
			result = { success = false, cash = 0, rep = 0, reason = "That run didn't add up, so it was not paid." }
		end
	end

	local cash, rep = Economy.applyJobResult(p, run.jobId, result, os.time())
	DataService.markDirty(player, true)
	StateService.push(player)

	Net.Job:FireClient(player, {
		kind = "result",
		jobId = run.jobId,
		name = JobsConfig.Jobs[run.jobId].name,
		success = result.success == true,
		reason = result.reason,
		cash = cash,
		rep = rep,
		medal = result.medal,
		raceTime = result.raceTime,
	})
	print(string.format("[Payout] user=%d job=%s success=%s cash=%d rep=%d t=%.1f", player.UserId, run.jobId, tostring(result.success == true), cash, rep, nowClock - run.startedAt))

	if run.jobId == "courier" then
		TutorialService.event(player, if result.success then "deliver" else "courierFailed")
	elseif run.jobId == "race" and result.success then
		TutorialService.event(player, "drive")
	end
end

function JobService.abandon(player: Player, reason: string)
	if active[player] then
		finish(player, { success = false, abandoned = true, cash = 0, rep = 0, reason = reason })
	end
end

function JobService.isBusy(player: Player): boolean
	return active[player] ~= nil
end

local function startJob(player: Player, jobId: string): (boolean, string?)
	if active[player] then
		return false, "Finish or cancel your current job first."
	end
	local p = DataService.profile(player)
	local root, hum = rootOf(player)
	if not p or not root or not hum or hum.Health <= 0 then
		return false, "You can't start a job right now."
	end
	local ok, err = Economy.canStartJob(p, jobId, os.time(), VehicleService.isDriving(player))
	if not ok then
		return false, err
	end
	local now = os.clock()
	local job
	if jobId == "courier" then
		job = JobModules.courier.new(p, now, function(n)
			return rng:NextInteger(1, n)
		end, flatPos(root))
	else
		job = JobModules[jobId].new(p, now)
	end
	local pos = flatPos(root)
	active[player] = { job = job, jobId = jobId, startedAt = now, startPos = pos, lastPos = pos, lastT = now }
	sendObjective(player, active[player])
	if jobId == "courier" then
		TutorialService.event(player, "start")
	end
	return true, JobsConfig.Jobs[jobId].name .. " started! Follow the light beam."
end

local function tick()
	local now = os.clock()
	for player, run in active do
		local root, hum = rootOf(player)
		local alive = hum ~= nil and hum.Health > 0
		local pos = if root then flatPos(root) else nil

		-- teleport / speed sanity between samples
		if pos and run.lastPos then
			local dt = now - run.lastT
			if dt > 0.05 then
				local speed = Layout.distance(pos, run.lastPos) / dt
				if speed > JobsConfig.MaxPlausibleSpeed * 1.3 and Layout.distance(pos, run.lastPos) > 25 then
					JobService.flag(player, string.format("moved %.0f studs/s during %s", speed, run.jobId))
					finish(player, { success = false, abandoned = true, cash = 0, rep = 0, reason = "Job cancelled: movement check failed." })
					continue
				end
			end
		end
		run.lastPos = pos
		run.lastT = now

		local ctx = { now = now, pos = pos, alive = alive, inVehicle = VehicleService.isDriving(player) }
		local result, message = run.job:update(ctx)
		if result then
			finish(player, result)
		else
			if message then
				Net.notify(player, message, "job")
				sendObjective(player, run)
			end
			if run.jobId == "heist" then
				setLootBag(player, run, run.job:carryingLoot())
			end
		end
	end
end

function JobService.start()
	Net.on("StartJob", function(player, arg)
		local jobId = Validate.knownId(arg, JobsConfig.Jobs)
		if not jobId then
			return false, "Unknown job."
		end
		return startJob(player, jobId)
	end)
	Net.on("CancelJob", function(player)
		if not active[player] then
			return false, "You're not on a job."
		end
		JobService.abandon(player, "Job cancelled. Back to free roam.")
		return true, nil
	end)

	VehicleService.onFlag(JobService.flag)

	local function hookCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if hum then
			hum.Died:Connect(function()
				JobService.abandon(player, "You got knocked out - job failed. No payout this time.")
			end)
		end
	end
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			hookCharacter(player, char)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(char)
			hookCharacter(player, char)
		end)
		if player.Character then
			task.spawn(hookCharacter, player, player.Character)
		end
	end

	task.spawn(function()
		local sinceObjective = 0
		while true do
			local dt = task.wait(TICK)
			tick()
			sinceObjective += dt
			if sinceObjective >= OBJECTIVE_PUSH_EVERY then
				sinceObjective = 0
				for player, run in active do
					sendObjective(player, run)
				end
			end
		end
	end)
end

-- Main calls this from PlayerRemoving *before* DataService.release so the abandon is saved.
function JobService.onPlayerLeaving(player: Player)
	JobService.abandon(player, "left the game")
	flags[player] = nil
end

return JobService
