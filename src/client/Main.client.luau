--!strict
-- Client bootstrap: presentation and input only. All game state lives on the server.

local Controllers = script.Parent.Controllers
local Store = require(script.Parent.Store)
local HUD = require(Controllers.HUD)
local Menus = require(Controllers.Menus)
local Waypoint = require(Controllers.Waypoint)
local VehicleController = require(Controllers.VehicleController)
local Input = require(Controllers.Input)

HUD.start()
Menus.start()
HUD.onPhone(function(tab)
	Menus.toggle(tab)
end)
Waypoint.start()
VehicleController.start()
Input.start()
Store.start()
