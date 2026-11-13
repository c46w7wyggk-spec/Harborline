--!strict
-- Arcade driving for the local player's own car.
-- Input comes from VehicleSeat.ThrottleFloat / SteerFloat, which Roblox's default control
-- scripts fill from keyboard (WASD/arrows), gamepad (thumbstick + triggers) and the touch
-- thumbstick, so all three input types share this one code path.
-- The driver owns the car's physics; the server enforces max speed (VehicleService watchdog).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VehicleController = {}

local REVERSE_FRACTION = 0.4
local BRAKE_MULT = 2.2
local COAST_DECEL = 18

local speed = 0 -- signed forward speed, studs/s

local function currentSeat(): (VehicleSeat?, BasePart?)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return nil, nil
	end
	local model = seat.Parent
	local chassis = model and model:FindFirstChild("Chassis") :: BasePart?
	if not chassis or chassis:GetAttribute("OwnerId") ~= Players.LocalPlayer.UserId then
		return nil, nil
	end
	return seat :: VehicleSeat, chassis
end

local function step(dt: number)
	local seat, chassis = currentSeat()
	if not seat or not chassis then
		speed = 0
		return
	end
	local move = chassis:FindFirstChild("Move") :: LinearVelocity?
	local turn = chassis:FindFirstChild("Turn") :: AngularVelocity?
	if not move or not turn then
		return
	end
	local maxSpeed = (chassis:GetAttribute("MaxSpeed") :: number) or 50
	local accel = (chassis:GetAttribute("Accel") :: number) or 30
	local turnRate = (chassis:GetAttribute("TurnRate") :: number) or 2

	local throttle = seat.ThrottleFloat
	local steer = seat.SteerFloat

	if throttle > 0.05 then
		local rate = if speed < 0 then accel * BRAKE_MULT else accel
		speed = math.min(speed + rate * throttle * dt, maxSpeed * throttle)
	elseif throttle < -0.05 then
		local rate = if speed > 0 then accel * BRAKE_MULT else accel * 0.7
		speed = math.max(speed + rate * throttle * dt, -maxSpeed * REVERSE_FRACTION)
	else
		local decel = COAST_DECEL * dt
		speed = if math.abs(speed) <= decel then 0 else speed - math.sign(speed) * decel
	end

	-- If we hit something hard, bleed speed so we don't keep pushing into a wall.
	local actual = chassis.AssemblyLinearVelocity
	local actualPlanar = Vector3.new(actual.X, 0, actual.Z).Magnitude
	if math.abs(speed) > 10 and actualPlanar < math.abs(speed) * 0.3 then
		speed *= 0.9
	end

	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 0.01 then
		flat = flat.Unit
	end
	local v = flat * speed
	move.PlaneVelocity = Vector2.new(v.X, v.Z)

	-- steering grip grows with speed and reverses when backing up
	local grip = math.clamp(math.abs(speed) / 12, 0, 1)
	local yaw = -steer * turnRate * grip * (if speed < 0 then -1 else 1)
	turn.AngularVelocity = Vector3.new(0, yaw, 0)
end

function VehicleController.speed(): number
	return speed
end

function VehicleController.start()
	RunService.Heartbeat:Connect(step)
end

return VehicleController
