--!strict
-- Keyboard / gamepad shortcuts. Touch players use the on-screen buttons.
--   J or gamepad Y : open/close the phone
--   Escape / gamepad B (while open) : close the phone

local ContextActionService = game:GetService("ContextActionService")

local Menus = require(script.Parent.Menus)

local Input = {}

function Input.start()
	ContextActionService:BindAction("HarborlinePhone", function(_, state)
		if state == Enum.UserInputState.Begin then
			Menus.toggle("jobs")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.J, Enum.KeyCode.ButtonY)

	ContextActionService:BindAction("HarborlineClose", function(_, state)
		if state == Enum.UserInputState.Begin and Menus.isOpen() then
			Menus.close()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace)
end

return Input
