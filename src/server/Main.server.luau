--!strict
-- Server bootstrap. Order matters: remotes exist before players can call them, the world exists
-- before characters spawn, and on leave the job is abandoned *before* the profile is saved.

local Players = game:GetService("Players")

local Services = script.Parent.Services
local Net = require(Services.Net)
local DataService = require(Services.DataService)
local StateService = require(Services.StateService)
local TutorialService = require(Services.TutorialService)
local VehicleService = require(Services.VehicleService)
local JobService = require(Services.JobService)
local ShopService = require(Services.ShopService)
local WorldBuilder = require(Services.WorldBuilder)

WorldBuilder.build()
Net.start()
StateService.start()
TutorialService.start()
VehicleService.start()
JobService.start()
ShopService.start()

DataService.onLoaded(function(player, session)
	ShopService.markActive(player)
	StateService.push(player)
	if not session.canSave then
		Net.notify(player, "Studio test mode: progress is NOT being saved.", "warn")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	JobService.onPlayerLeaving(player) -- voids any active job and records its cooldown
	DataService.release(player) -- then save and release the session lock
end)

DataService.start()

print(string.format("[Harborline] server ready (store=%s, studio=%s)", DataService.STORE_NAME, tostring(DataService.IS_STUDIO)))
