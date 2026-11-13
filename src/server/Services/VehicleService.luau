--!strict
-- Spawns owned vehicles, restricts seats to their owner, hands physics to the driver,
-- and watches for impossible speeds.
--
-- Car model contract (read by client VehicleController):
--   Model "Car_<userId>" with PrimaryPart "Chassis" (attributes OwnerId, MaxSpeed, Accel, TurnRate)
--   Chassis has Attachment "Drive", LinearVelocity "Move" (XZ plane), AngularVelocity "Turn".
--   VehicleSeat "Seat" welded to the chassis.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Layout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local Validate = require(ReplicatedStorage.Shared.Validate)
local DataService = require(script.Parent.DataService)
local Net = require(script.Parent.Net)

local SPAWN_COOLDOWN = 6
local SPEED_TOLERANCE = 1.25

local VehicleService = {}
local cars: { [Player]: Model } = {}
local lastSpawn: { [Player]: number } = {}
local overSpeedSamples: { [Player]: number } = {}
local flagCallback: ((Player, string) -> ())? = nil

local carsFolder = Instance.new("Folder")
carsFolder.Name = "Vehicles"

function VehicleService.onFlag(cb: (Player, string) -> ())
	flagCallback = cb
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	for k, v in props do
		(p :: any)[k] = v
	end
	return p
end

local function build(player: Player, def: Progression.VehicleDef, cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Car_" .. player.UserId
	local sx, sy, sz = def.size[1], def.size[2], def.size[3]
	local color = Color3.fromRGB(def.color[1], def.color[2], def.color[3])

	local chassis = part({
		Name = "Chassis",
		Size = Vector3.new(sx, sy, sz),
		CFrame = cf * CFrame.new(0, sy / 2 + 1.4, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 100, 1),
	})
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- cabin
	local cabin = part({
		Name = "Cabin",
		Size = Vector3.new(sx * 0.85, sy * 0.7, sz * 0.45),
		CFrame = chassis.CFrame * CFrame.new(0, sy * 0.85, sz * 0.08),
		Color = Color3.fromRGB(40, 50, 70),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
		CanCollide = false,
		Massless = true,
	})
	cabin.Parent = model
	weld(chassis, cabin)

	-- wheels: a visual cylinder plus an invisible low-friction ball that actually touches the
	-- ground, so the car rides over curbs and plaza edges instead of snagging on them.
	for _, offset in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		local wheelCf = chassis.CFrame * CFrame.new(offset.X * (sx / 2), -sy / 2 + 0.8, offset.Z * (sz / 2 - 1.8))
		local wheel = part({
			Name = "Wheel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 2.6, 2.6),
			CFrame = wheelCf,
			Color = Color3.fromRGB(25, 25, 25),
			CanCollide = false,
			Massless = true,
		})
		wheel.Parent = model
		weld(chassis, wheel)
		local skid = part({
			Name = "Skid",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = wheelCf,
			Transparency = 1,
			CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1),
		})
		skid.Parent = model
		weld(chassis, skid)
	end

	-- headlights
	for _, x in { -sx / 2 + 1, sx / 2 - 1 } do
		local light = part({
			Name = "Headlight",
			Size = Vector3.new(1.2, 0.6, 0.2),
			CFrame = chassis.CFrame * CFrame.new(x, 0, -sz / 2 - 0.1),
			Color = Color3.fromRGB(255, 250, 210),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Massless = true,
		})
		light.Parent = model
		weld(chassis, light)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = chassis.CFrame * CFrame.new(0, sy / 2 + 0.5, sz * 0.05)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.MaxSpeed = 0 -- the seat itself applies no force; VehicleController drives the constraints
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Parent = model
	weld(chassis, seat)

	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = chassis

	local move = Instance.new("LinearVelocity")
	move.Name = "Move"
	move.Attachment0 = att
	move.RelativeTo = Enum.ActuatorRelativeTo.World
	move.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	move.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	move.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	move.PlaneVelocity = Vector2.zero
	move.MaxForce = 60000
	move.Parent = chassis

	local turn = Instance.new("AngularVelocity")
	turn.Name = "Turn"
	turn.Attachment0 = att
	turn.RelativeTo = Enum.ActuatorRelativeTo.World
	turn.AngularVelocity = Vector3.zero
	turn.MaxTorque = 400000 -- also keeps the car upright (city is flat)
	turn.Parent = chassis

	chassis:SetAttribute("OwnerId", player.UserId)
	chassis:SetAttribute("VehicleId", def.id)
	chassis:SetAttribute("MaxSpeed", def.maxSpeed)
	chassis:SetAttribute("Accel", def.accel)
	chassis:SetAttribute("TurnRate", def.turnRate)
	model:AddTag("Vehicle")

	-- Only the owner may sit. The driver gets network ownership for responsive handling.
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = seat.Occupant
		if not hum then
			if chassis.Parent then
				move.PlaneVelocity = Vector2.zero
				turn.AngularVelocity = Vector3.zero
				pcall(chassis.SetNetworkOwner, chassis, nil)
			end
			return
		end
		local occupant = Players:GetPlayerFromCharacter(hum.Parent)
		if occupant ~= player then
			local weldInst = seat:FindFirstChild("SeatWeld")
			if weldInst then
				weldInst:Destroy()
			end
			hum.Sit = false
			return
		end
		pcall(chassis.SetNetworkOwner, chassis, player)
	end)

	-- "Drive" prompt: reliable way in on every platform (touching the seat is fiddly on phones).
	local drive = Instance.new("ProximityPrompt")
	drive.Name = "DrivePrompt"
	drive.ActionText = "Drive"
	drive.ObjectText = def.name
	drive.KeyboardKeyCode = Enum.KeyCode.E
	drive.GamepadKeyCode = Enum.KeyCode.ButtonX
	drive.MaxActivationDistance = 12
	drive.RequiresLineOfSight = false
	drive.Parent = chassis
	drive.Triggered:Connect(function(who)
		if who ~= player or seat.Occupant then
			return
		end
		local hum = who.Character and who.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 and not hum.SeatPart then
			seat:Sit(hum)
		end
	end)

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- stream the whole car at once
	model.Parent = carsFolder
	-- server owns an empty car, so a nearby player can't take its physics and fling it
	pcall(chassis.SetNetworkOwner, chassis, nil)
	return model
end

function VehicleService.despawn(player: Player)
	local car = cars[player]
	if car then
		car:Destroy()
		cars[player] = nil
	end
	overSpeedSamples[player] = nil
end

local ON_FOOT_CAP = 40 -- walk 16, plus jumps/falls/ragdoll slides

-- Fastest legitimate speed for the player's current mode of travel (used by movement checks).
function VehicleService.speedCap(player: Player): number
	local car = cars[player]
	if car and VehicleService.isDriving(player) and car.PrimaryPart then
		return math.max(ON_FOOT_CAP, (car.PrimaryPart:GetAttribute("MaxSpeed") :: number?) or ON_FOOT_CAP)
	end
	return ON_FOOT_CAP
end

-- Is the player currently driving their own car?
function VehicleService.isDriving(player: Player): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local car = cars[player]
	return seat ~= nil and car ~= nil and seat:IsDescendantOf(car)
end

-- Find a clear patch of ground next to the player (on a road or plaza) to drop the car.
local function findSpawnCFrame(root: BasePart, size: Vector3): CFrame?
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { root.Parent :: Instance }
	for _, tagged in CollectionService:GetTagged("Ground") do
		table.insert(exclude, tagged)
	end
	params.FilterDescendantsInstances = exclude
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)
	local base = Vector3.new(root.Position.X, 0, root.Position.Z)
	for _, offset in { right * 10, -right * 10, look * 12, -look * 12, right * 18, -right * 18 } do
		local pos = base + offset
		if math.abs(pos.X) < Layout.MAP_HALF and pos.Z > -Layout.MAP_HALF and pos.Z < Layout.WATER_Z - 30 then
			local cf = CFrame.lookAt(pos, pos + look)
			local hits = workspace:GetPartBoundsInBox(cf * CFrame.new(0, size.Y / 2 + 2, 0), size + Vector3.new(2, 2, 2), params)
			if #hits == 0 then
				return cf
			end
		end
	end
	return nil
end

function VehicleService.spawn(player: Player, vehicleId: string): (boolean, string?)
	local p = DataService.profile(player)
	local def = Progression.vehicleById(vehicleId)
	if not p or not def then
		return false, "Unknown vehicle."
	end
	if not p.ownedVehicles[def.id] then
		return false, "You don't own the " .. def.name .. " yet."
	end
	local now = os.clock()
	if lastSpawn[player] and now - lastSpawn[player] < SPAWN_COOLDOWN then
		return false, "Your last car just arrived - wait a moment."
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root or hum.Health <= 0 then
		return false, "You can't do that right now."
	end
	if hum.SeatPart then
		return false, "Hop out first."
	end
	local cf = findSpawnCFrame(root, Vector3.new(def.size[1], def.size[2] + 3, def.size[3]))
	if not cf then
		return false, "No room here. Step onto an open road and try again."
	end
	VehicleService.despawn(player)
	lastSpawn[player] = now
	cars[player] = build(player, def, cf)
	return true, def.name .. " delivered! Walk up and sit to drive."
end

VehicleService._buildForTest = build

function VehicleService.start()
	carsFolder.Parent = workspace

	Net.on("SpawnVehicle", function(player, arg)
		if not Validate.id(arg) then
			return false, "Unknown vehicle."
		end
		return VehicleService.spawn(player, arg :: string)
	end)
	Net.on("DespawnVehicle", function(player)
		VehicleService.despawn(player)
		return true, "Vehicle returned to the garage."
	end)

	Players.PlayerRemoving:Connect(function(player)
		VehicleService.despawn(player)
		lastSpawn[player] = nil
	end)

	-- Speed watchdog (driver-owned physics can be tampered with).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		for player, car in cars do
			local chassis = car.PrimaryPart
			if not chassis or not chassis.Parent then
				continue
			end
			local max = (chassis:GetAttribute("MaxSpeed") :: number) or 50
			local v = chassis.AssemblyLinearVelocity
			local planar = Vector3.new(v.X, 0, v.Z).Magnitude
			if planar > max * SPEED_TOLERANCE then
				overSpeedSamples[player] = (overSpeedSamples[player] or 0) + 1
				if overSpeedSamples[player] >= 4 and flagCallback then
					overSpeedSamples[player] = 0
					flagCallback(player, "vehicle overspeed")
				end
			else
				overSpeedSamples[player] = math.max(0, (overSpeedSamples[player] or 0) - 1)
			end
			-- fell out of the world: tidy up
			if chassis.Position.Y < -50 then
				VehicleService.despawn(player)
				Net.notify(player, "Your car fell off the map and was returned to the garage.", "warn")
			end
		end
	end)
end

return VehicleService
