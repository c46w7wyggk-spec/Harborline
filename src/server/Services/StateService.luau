--!strict
-- Builds the read-only snapshot each client renders (HUD, menus, next goal) and pushes it.
-- Clients never receive anything they could use to change state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local JobsConfig = require(ReplicatedStorage.Shared.Config.Jobs)
local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local StateService = {}
local pending: { [Player]: boolean } = {}

local function snapshot(player: Player)
	local session = DataService.get(player)
	if not session then
		return nil
	end
	local p = session.data
	local now = os.time()
	local level = Economy.level(p)
	local cooldowns = {}
	for _, id in JobsConfig.Order do
		local readyAt = p.cooldowns[id]
		cooldowns[id] = if readyAt and readyAt > now then readyAt - now else 0
	end
	local biz = Economy.businessLevel(p)
	local nextBiz = Economy.nextBusinessLevel(p)
	local owned = {}
	for id in p.ownedVehicles do
		table.insert(owned, id)
	end
	local tut = Tutorial.step(p.tutorialStep)
	return {
		cash = p.cash,
		rep = p.rep,
		level = level,
		levelRep = Progression.RepLevels[level],
		nextLevelRep = Progression.RepLevels[level + 1],
		owned = owned,
		business = {
			level = p.business.level,
			name = if biz then biz.name else nil,
			stash = p.business.stash,
			cap = if biz then biz.stashCap else 0,
			incomePerMin = if biz then biz.incomePerMin else 0,
			nextName = if nextBiz then nextBiz.name else nil,
			nextCost = if nextBiz then nextBiz.cost else nil,
			nextRepLevel = if nextBiz then nextBiz.repLevel else nil,
		},
		cooldowns = cooldowns,
		freshness = table.clone(p.freshness),
		firstRunDone = table.clone(p.firstRunDone),
		tutorial = if tut then { step = p.tutorialStep, text = tut.text, target = tut.target, total = Tutorial.COUNT } else nil,
		goal = Economy.nextGoal(p, now),
		memoryMode = not session.canSave,
	}
end

-- Coalesce several changes in one frame into one push.
function StateService.push(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		if player.Parent then
			local snap = snapshot(player)
			if snap then
				Net.State:FireClient(player, snap)
			end
		end
	end)
end

function StateService.start()
	Net.on("GetState", function(player)
		StateService.push(player)
		return true, nil
	end)
end

return StateService
