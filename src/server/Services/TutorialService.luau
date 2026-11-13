--!strict
-- Advances onboarding steps on server-observed events. Never grants rewards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tutorial = require(ReplicatedStorage.Shared.Tutorial)
local Layout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)
local Net = require(script.Parent.Net)

local TutorialService = {}

local function alreadySatisfied(p: any, id: string): boolean
	if id == "buy" then
		return p.business.level >= 1
	elseif id == "drive" then
		return p.firstRunDone.race == true
	elseif id == "deliver" or id == "start" then
		return p.firstRunDone.courier == true
	end
	return false
end

local function setStep(player: Player, p: any, index: number)
	while index <= Tutorial.COUNT and alreadySatisfied(p, Tutorial.STEPS[index].id) do
		index += 1
	end
	if index ~= p.tutorialStep then
		p.tutorialStep = index
		DataService.markDirty(player)
		StateService.push(player)
		if index == Tutorial.DONE then
			Net.notify(player, "Tutorial complete! Your next goal is always shown bottom-left.", "success")
		end
	end
end

-- Called by other services: "start", "deliver", "buy", "drive", or "courierFailed".
function TutorialService.event(player: Player, id: string)
	local p = DataService.profile(player)
	if not p or p.tutorialStep >= Tutorial.DONE then
		return
	end
	local current = Tutorial.STEPS[p.tutorialStep]
	if id == "courierFailed" and current.id == "deliver" then
		setStep(player, p, Tutorial.indexOf("start"))
		return
	end
	if current.id == id or alreadySatisfied(p, current.id) then
		setStep(player, p, p.tutorialStep + 1)
	end
end

function TutorialService.start()
	Net.on("SkipTutorial", function(player)
		local p = DataService.profile(player) :: any
		p.tutorialStep = Tutorial.DONE
		DataService.markDirty(player)
		StateService.push(player)
		return true, "Tutorial skipped. Follow the goal card bottom-left."
	end)

	-- Step 1: reaching the Job Board on foot.
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				local p = DataService.profile(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if p and root and p.tutorialStep == 1 then
					local pos = { x = root.Position.X, z = root.Position.Z }
					if Layout.distance(pos, Layout.Places.JobBoard) < 16 then
						TutorialService.event(player, "board")
					end
				end
			end
		end
	end)
end

return TutorialService
