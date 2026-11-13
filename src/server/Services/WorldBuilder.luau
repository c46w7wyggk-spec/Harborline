--!strict
-- Generates the Harborline district from Config/WorldLayout at server start.
-- Deterministic (fixed seed), all anchored, low part count for mobile.
-- Interactive spots get ProximityPrompts whose Triggered handler opens a client menu.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Layout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local Net = require(script.Parent.Net)

local WorldBuilder = {}

local C = {
	grass = Color3.fromRGB(110, 170, 95),
	asphalt = Color3.fromRGB(52, 54, 62),
	lane = Color3.fromRGB(245, 205, 70),
	lot = Color3.fromRGB(196, 190, 178),
	plaza = Color3.fromRGB(232, 214, 186),
	water = Color3.fromRGB(40, 130, 200),
	wall = Color3.fromRGB(150, 150, 160),
	neonPink = Color3.fromRGB(255, 80, 160),
	neonCyan = Color3.fromRGB(60, 230, 255),
	neonGold = Color3.fromRGB(255, 200, 60),
}
local BUILDING_COLORS = {
	Color3.fromRGB(238, 132, 110),
	Color3.fromRGB(246, 190, 120),
	Color3.fromRGB(130, 190, 220),
	Color3.fromRGB(170, 150, 210),
	Color3.fromRGB(240, 230, 210),
	Color3.fromRGB(120, 200, 170),
	Color3.fromRGB(230, 120, 150),
}

local root: Folder

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end

-- Huge ground/road parts: keep them always streamed in so the floor never vanishes at map corners.
local function persistentModel(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	m.Parent = root
	return m
end

local function at(pt: Layout.Point, y: number): Vector3
	return Vector3.new(pt.x, y, pt.z)
end

local function sign(parent: Instance, text: string, cf: CFrame, size: Vector2, color: Color3, textColor: Color3?)
	local board = part(parent, {
		Name = "Sign",
		Size = Vector3.new(size.X, size.Y, 0.6),
		CFrame = cf,
		Color = color,
		Material = Enum.Material.Neon,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 20
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = textColor or Color3.new(1, 1, 1)
		label.Parent = gui
		gui.Parent = board
	end
	return board
end

local function billboard(parent: BasePart, text: string, color: Color3, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffsetWorldSpace = Vector3.new(0, parent.Size.Y / 2 + 4, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parent
end

local function prompt(parent: BasePart, action: string, object: string, menuId: string)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.MaxActivationDistance = 14
	pp.RequiresLineOfSight = false
	pp.Parent = parent
	pp.Triggered:Connect(function(player)
		Net.OpenMenu:FireClient(player, menuId)
	end)
end

---------------------------------------------------------------------------- ground, water, roads

local function buildGround()
	local f = persistentModel("Ground")
	local half = Layout.MAP_HALF + 40
	local depth = (Layout.WATER_Z + 20) - (-half)
	local ground = part(f, {
		Name = "Land",
		Size = Vector3.new(half * 2, 4, depth),
		CFrame = CFrame.new(0, -2, (-half + Layout.WATER_Z + 20) / 2),
		Color = C.grass,
		Material = Enum.Material.Grass,
	})
	ground:AddTag("Ground")
	part(f, {
		Name = "Water",
		Size = Vector3.new(half * 2 + 400, 2, 500),
		CFrame = CFrame.new(0, -3, Layout.WATER_Z + 20 + 250),
		Color = C.water,
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	-- seawall railing and invisible map edge walls keep cars on land
	part(f, {
		Name = "Seawall",
		Size = Vector3.new(half * 2, 3, 2),
		CFrame = CFrame.new(0, 1.5, Layout.HARBOR_BLVD_Z + 40),
		Color = C.wall,
		Material = Enum.Material.Concrete,
	})
	for _, spec in {
		{ Vector3.new(4, 60, depth), Vector3.new(half, 30, (-half + Layout.WATER_Z) / 2) },
		{ Vector3.new(4, 60, depth), Vector3.new(-half, 30, (-half + Layout.WATER_Z) / 2) },
		{ Vector3.new(half * 2, 60, 4), Vector3.new(0, 30, -half) },
	} do
		part(f, { Name = "EdgeWall", Size = spec[1], Position = spec[2], Transparency = 1 })
	end
end

local function buildRoads()
	local f = persistentModel("Roads")
	local w = Layout.ROAD_WIDTH
	local half = Layout.MAP_HALF
	local north, south = -half - w / 2, Layout.HARBOR_BLVD_Z + w / 2
	-- north-south roads
	for x = -half, half, Layout.BLOCK do
		local len = south - north
		local road = part(f, {
			Name = "Road",
			Size = Vector3.new(w, 0.2, len),
			Position = Vector3.new(x, 0.1, (north + south) / 2),
			Color = C.asphalt,
			Material = Enum.Material.Asphalt,
		})
		road:AddTag("Ground")
		part(f, { Name = "Lane", Size = Vector3.new(0.6, 0.05, len), Position = Vector3.new(x, 0.22, (north + south) / 2), Color = C.lane, CanCollide = false })
	end
	-- east-west roads (grid plus Harbor Boulevard)
	local zs = {}
	for z = -half, Layout.HARBOR_BLVD_Z - Layout.BLOCK, Layout.BLOCK do
		table.insert(zs, z)
	end
	table.insert(zs, Layout.HARBOR_BLVD_Z)
	for _, z in zs do
		local road = part(f, {
			Name = if z == Layout.HARBOR_BLVD_Z then "HarborBoulevard" else "Road",
			Size = Vector3.new(half * 2 + w, 0.2, w),
			Position = Vector3.new(0, 0.12, z),
			Color = C.asphalt,
			Material = Enum.Material.Asphalt,
		})
		road:AddTag("Ground")
		part(f, { Name = "Lane", Size = Vector3.new(half * 2 + w, 0.05, 0.6), Position = Vector3.new(0, 0.24, z), Color = C.lane, CanCollide = false })
	end
end

---------------------------------------------------------------------------- city blocks

local SPECIAL_BLOCKS: { [string]: boolean } = {}
local function blockKey(cx: number, cz: number): string
	return cx .. "," .. cz
end
for _, k in {
	-- hub plaza (four blocks around the origin)
	{ -100, -100 },
	{ 100, -100 },
	{ -100, 100 },
	{ 100, 100 },
	{ 300, -300 }, -- Old Mint
	{ 300, 300 }, -- park + ferris wheel
	{ -700, 500 }, -- warehouse yard
	{ -300, -100 }, -- depot
} do
	SPECIAL_BLOCKS[blockKey(k[1], k[2])] = true
end

local function buildBlocks()
	local f = folder("Buildings")
	local rng = Random.new(20261113)
	local inner = Layout.BLOCK - Layout.ROAD_WIDTH - 12
	for cx = -Layout.MAP_HALF + Layout.BLOCK / 2, Layout.MAP_HALF - Layout.BLOCK / 2, Layout.BLOCK do
		for cz = -Layout.MAP_HALF + Layout.BLOCK / 2, Layout.HARBOR_BLVD_Z - Layout.BLOCK, Layout.BLOCK do
			if SPECIAL_BLOCKS[blockKey(cx, cz)] then
				continue
			end
			part(f, {
				Name = "Lot",
				Size = Vector3.new(inner + 8, 0.4, inner + 8),
				Position = Vector3.new(cx, 0.2, cz),
				Color = C.lot,
				Material = Enum.Material.Concrete,
			})
			-- 2x2 buildings per block, sometimes a little park instead
			local sub = inner / 2 - 6
			for ix = -1, 1, 2 do
				for iz = -1, 1, 2 do
					local px, pz = cx + ix * (inner / 4 + 1), cz + iz * (inner / 4 + 1)
					if rng:NextNumber() < 0.15 then
						local trunk = part(f, { Name = "Tree", Size = Vector3.new(3, 14, 3), Position = Vector3.new(px, 7, pz), Color = Color3.fromRGB(110, 80, 55) })
						part(f, {
							Name = "Leaves",
							Shape = Enum.PartType.Ball,
							Size = Vector3.new(18, 18, 18),
							Position = trunk.Position + Vector3.new(0, 12, 0),
							Color = Color3.fromRGB(80, 160, 80),
							Material = Enum.Material.Grass,
						})
						continue
					end
					local h = rng:NextInteger(26, if math.abs(cx) + math.abs(cz) < 600 then 130 else 70)
					local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
					local b = part(f, {
						Name = "Building",
						Size = Vector3.new(sub, h, sub),
						Position = Vector3.new(px, h / 2 + 0.4, pz),
						Color = color,
						Material = Enum.Material.Concrete,
					})
					-- one band of "windows" and a roof cap for readability at distance
					part(f, {
						Name = "Windows",
						Size = Vector3.new(sub + 0.4, math.min(6, h * 0.2), sub + 0.4),
						Position = b.Position + Vector3.new(0, h * 0.2, 0),
						Color = Color3.fromRGB(60, 80, 110),
						Material = Enum.Material.Glass,
						CanCollide = false,
					})
					part(f, {
						Name = "Roof",
						Size = Vector3.new(sub + 1, 1.5, sub + 1),
						Position = b.Position + Vector3.new(0, h / 2 + 0.75, 0),
						Color = color:Lerp(Color3.new(0, 0, 0), 0.35),
					})
				end
			end
		end
	end
	-- low shops along the narrow strip between the last grid road and Harbor Boulevard
	local stripZ = (Layout.HARBOR_BLVD_Z + (Layout.HARBOR_BLVD_Z - Layout.BLOCK)) / 2 + 50
	for x = -Layout.MAP_HALF + Layout.BLOCK / 2, Layout.MAP_HALF - Layout.BLOCK / 2, Layout.BLOCK do
		part(f, {
			Name = "Shopfront",
			Size = Vector3.new(120, 18, 40),
			Position = Vector3.new(x, 9, stripZ),
			Color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)],
			Material = Enum.Material.Brick,
		})
	end
end

---------------------------------------------------------------------------- hub plaza

local function buildHub()
	local f = folder("Hub")
	part(f, {
		Name = "Plaza",
		Size = Vector3.new(360, 0.6, 360),
		Position = Vector3.new(0, 0.3, 0),
		Color = C.plaza,
		Material = Enum.Material.Pavement,
	})
	-- spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(16, 1, 16)
	spawn.Position = at(Layout.Spawn, 0.8)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = C.neonCyan
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.CanCollide = true
	spawn.Parent = f

	-- fountain landmark
	part(f, { Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 30, 30), CFrame = CFrame.new(0, 1.5, -50) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble })
	part(f, { Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 26, 26), CFrame = CFrame.new(0, 3.1, -50) * CFrame.Angles(0, 0, math.rad(90)), Color = C.water, Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false })

	-- Job Board
	local jb = Layout.Places.JobBoard
	local board = part(f, { Name = "JobBoard", Size = Vector3.new(16, 10, 1.5), CFrame = CFrame.new(jb.x, 7, jb.z) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(40, 40, 60) })
	sign(f, "JOB BOARD", board.CFrame * CFrame.new(0, 7, 0), Vector2.new(16, 3.5), C.neonGold, Color3.fromRGB(40, 30, 10))
	for _, x in { -7, 7 } do
		part(f, { Name = "Post", Size = Vector3.new(1, 12, 1), Position = Vector3.new(jb.x + x, 6, jb.z), Color = Color3.fromRGB(60, 60, 70) })
	end
	prompt(board, "Browse jobs", "Job Board", "jobs")
	board:AddTag("Interact")

	-- Car Lot
	local cl = Layout.Places.CarLot
	local dealer = part(f, { Name = "CarLotKiosk", Size = Vector3.new(10, 8, 6), Position = Vector3.new(cl.x, 4, cl.z), Color = Color3.fromRGB(60, 90, 160) })
	sign(f, "CAR LOT", CFrame.new(cl.x, 11, cl.z), Vector2.new(14, 3), C.neonCyan, Color3.fromRGB(10, 30, 40))
	prompt(dealer, "Shop vehicles", "Car Lot", "dealer")
	-- display cars (static props)
	for i, col in { Color3.fromRGB(92, 200, 255), Color3.fromRGB(120, 200, 110), Color3.fromRGB(255, 90, 120) } do
		part(f, { Name = "DisplayCar", Size = Vector3.new(7, 3, 12), Position = Vector3.new(cl.x + 20 + i * 12, 2, cl.z - 10), Color = col })
	end

	-- Noodle Stand (business)
	local ns = Layout.Places.NoodleStand
	local stand = part(f, { Name = "NoodleStand", Size = Vector3.new(14, 7, 8), Position = Vector3.new(ns.x, 3.5, ns.z), Color = Color3.fromRGB(230, 90, 60), Material = Enum.Material.Wood })
	part(f, { Name = "Awning", Size = Vector3.new(16, 0.6, 11), CFrame = CFrame.new(ns.x, 8.5, ns.z - 1) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(255, 230, 120) })
	sign(f, "NOODLES", CFrame.new(ns.x, 11.5, ns.z), Vector2.new(12, 3), C.neonPink)
	prompt(stand, "Manage business", "Noodle Stand", "business")

	-- Clock tower landmark
	local ct = (Layout.Landmarks[3] :: any).pos
	part(f, { Name = "ClockTower", Size = Vector3.new(16, 70, 16), Position = Vector3.new(ct.x, 35, ct.z), Color = Color3.fromRGB(180, 140, 110), Material = Enum.Material.Brick })
	part(f, { Name = "ClockFace", Shape = Enum.PartType.Cylinder, Size = Vector3.new(17, 12, 12), CFrame = CFrame.new(ct.x, 58, ct.z), Color = Color3.fromRGB(250, 245, 220), Material = Enum.Material.Neon })
end

---------------------------------------------------------------------------- job locations

local function buildJobSites()
	local f = folder("Sites")

	-- Depot
	local d = Layout.Places.Depot
	local depot = part(f, { Name = "Depot", Size = Vector3.new(120, 30, 90), Position = Vector3.new(-300, 15, -110), Color = Color3.fromRGB(200, 120, 60), Material = Enum.Material.CorrodedMetal })
	sign(f, "HARBORLINE PARCEL DEPOT", CFrame.new(-300, 34, -64), Vector2.new(60, 6), C.neonGold, Color3.fromRGB(50, 30, 0))
	local pad = part(f, { Name = "DepotPickup", Size = Vector3.new(30, 0.4, 30), Position = at(d, 0.3), Color = C.neonGold, Material = Enum.Material.Neon, Transparency = 0.5, CanCollide = false })
	billboard(pad, "PARCEL PICKUP", C.neonGold, 300)
	for i = 1, 6 do
		part(f, { Name = "Crate", Size = Vector3.new(4, 4, 4), Position = Vector3.new(-340 + i * 8, 2, -60), Color = Color3.fromRGB(170, 120, 70), Material = Enum.Material.Wood })
	end
	local _ = depot

	-- Delivery addresses: a mailbox and a name label at each
	for _, a in Layout.Addresses do
		-- within the delivery radius, non-colliding so cars don't snag on it
		local box = part(f, { Name = "Mailbox_" .. a.id, Size = Vector3.new(2, 4, 2), Position = Vector3.new(a.pos.x + 8, 2, a.pos.z + 8), Color = Color3.fromRGB(60, 110, 220), CanCollide = false })
		local marker = part(f, { Name = "DropMarker_" .. a.id, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 30, 30), CFrame = CFrame.new(a.pos.x, 0.35, a.pos.z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 110, 220), Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false })
		local _ = marker
		billboard(box, a.name, Color3.new(1, 1, 1), 120)
	end

	-- Old Mint (Vault Job). A walled courtyard with an open gate facing the road to the south.
	local m = Layout.Places.OldMint
	local mf = folder("OldMint", f)
	local wallH, size = 26, 130
	local walls = {
		{ Vector3.new(size, wallH, 4), Vector3.new(m.x, wallH / 2, m.z - size / 2) },
		{ Vector3.new(4, wallH, size), Vector3.new(m.x - size / 2, wallH / 2, m.z) },
		{ Vector3.new(4, wallH, size), Vector3.new(m.x + size / 2, wallH / 2, m.z) },
		-- south wall with a 40-stud gate
		{ Vector3.new((size - 40) / 2, wallH, 4), Vector3.new(m.x - (size + 40) / 4, wallH / 2, m.z + size / 2) },
		{ Vector3.new((size - 40) / 2, wallH, 4), Vector3.new(m.x + (size + 40) / 4, wallH / 2, m.z + size / 2) },
	}
	for _, w in walls do
		part(mf, { Name = "MintWall", Size = w[1], Position = w[2], Color = Color3.fromRGB(215, 205, 180), Material = Enum.Material.Marble })
	end
	part(mf, { Name = "MintFloor", Size = Vector3.new(size, 0.6, size), Position = Vector3.new(m.x, 0.3, m.z), Color = Color3.fromRGB(180, 170, 150), Material = Enum.Material.Slate })
	sign(mf, "OLD MINT MUSEUM", CFrame.new(m.x, wallH + 5, m.z + size / 2), Vector2.new(50, 7), Color3.fromRGB(120, 220, 140), Color3.fromRGB(10, 40, 20))
	local mv = Layout.Places.MintVault
	part(mf, { Name = "VaultDoor", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 22, 22), CFrame = CFrame.new(mv.x, 11, mv.z - 18) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(150, 150, 165), Material = Enum.Material.DiamondPlate })
	local vaultPad = part(mf, { Name = "VaultPad", Size = Vector3.new(20, 0.3, 20), Position = at(mv, 0.7), Color = Color3.fromRGB(120, 220, 140), Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	billboard(vaultPad, "VAULT (Vault Job)", Color3.fromRGB(120, 220, 140), 250)

	-- Warehouse drop-off
	local wh = Layout.Places.Warehouse
	part(f, { Name = "Warehouse", Size = Vector3.new(110, 34, 60), Position = Vector3.new(wh.x, 17, wh.z - 50), Color = Color3.fromRGB(120, 110, 100), Material = Enum.Material.CorrodedMetal })
	sign(f, "DOCKSIDE WAREHOUSE", CFrame.new(wh.x, 38, wh.z - 19), Vector2.new(50, 6), C.neonPink)
	part(f, { Name = "WarehouseYard", Size = Vector3.new(150, 0.4, 150), Position = Vector3.new(wh.x, 0.2, wh.z), Color = Color3.fromRGB(150, 140, 120), Material = Enum.Material.Concrete })
	local drop = part(f, { Name = "DropZone", Size = Vector3.new(40, 0.4, 40), Position = at(wh, 0.5), Color = C.neonPink, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false })
	billboard(drop, "DROP-OFF", C.neonPink, 250)

	-- Race start/finish arch on Harbor Boulevard
	local rs = Layout.Places.RaceStart
	for _, x in { -26, 26 } do
		part(f, { Name = "ArchPost", Size = Vector3.new(3, 26, 3), Position = Vector3.new(rs.x + x, 13, rs.z), Color = Color3.new(1, 1, 1) })
	end
	sign(f, "HARBOR SPRINT  START / FINISH", CFrame.new(rs.x, 27, rs.z), Vector2.new(55, 5), Color3.fromRGB(20, 20, 20))
end

---------------------------------------------------------------------------- landmarks

local function buildLandmarks()
	local f = folder("Landmarks")
	-- Lighthouse on a small island in the harbor
	local lh = (Layout.Landmarks[1] :: any).pos
	part(f, { Name = "Island", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 60, 60), CFrame = CFrame.new(lh.x, -1, lh.z) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(210, 190, 140), Material = Enum.Material.Sand })
	for i = 0, 5 do
		part(f, {
			Name = "LighthouseBand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(10, 14 - i, 14 - i),
			CFrame = CFrame.new(lh.x, 7 + i * 10, lh.z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = if i % 2 == 0 then Color3.fromRGB(230, 60, 60) else Color3.new(1, 1, 1),
		})
	end
	local lamp = part(f, { Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(9, 9, 9), Position = Vector3.new(lh.x, 68, lh.z), Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 3
	light.Parent = lamp

	-- Ferris wheel in the park block
	local fw = (Layout.Landmarks[2] :: any).pos
	part(f, { Name = "Park", Size = Vector3.new(150, 0.4, 150), Position = Vector3.new(fw.x, 0.2, fw.z), Color = Color3.fromRGB(95, 180, 90), Material = Enum.Material.Grass })
	local center = Vector3.new(fw.x, 50, fw.z)
	local radius = 40
	local spokes = 12
	for i = 1, spokes do
		local a = (i / spokes) * math.pi * 2
		local cabinPos = center + Vector3.new(math.cos(a) * radius, math.sin(a) * radius, 0)
		part(f, { Name = "Spoke", Size = Vector3.new(1, 1, radius), CFrame = CFrame.lookAt((center + cabinPos) / 2, cabinPos), Color = Color3.new(1, 1, 1) })
		part(f, { Name = "Gondola", Size = Vector3.new(5, 5, 5), Position = cabinPos - Vector3.new(0, 3, 0), Color = BUILDING_COLORS[(i % #BUILDING_COLORS) + 1], Material = Enum.Material.Neon })
	end
	for _, x in { -14, 14 } do
		part(f, { Name = "WheelLeg", Size = Vector3.new(2, 52, 2), CFrame = CFrame.new(fw.x + x, 25, fw.z) * CFrame.Angles(0, 0, math.rad(x > 0 and 15 or -15)), Color = Color3.fromRGB(200, 200, 210) })
	end
end

local function setLighting()
	Lighting.ClockTime = 16.5
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(255, 205, 170)
	atmosphere.Decay = Color3.fromRGB(120, 110, 160)
	atmosphere.Parent = Lighting
end

function WorldBuilder.build()
	root = Instance.new("Folder")
	root.Name = "Harborline"
	buildGround()
	buildRoads()
	buildBlocks()
	buildHub()
	buildJobSites()
	buildLandmarks()
	setLighting()
	root.Parent = workspace
	local count = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	print(string.format("[World] Harborline built: %d parts", count))
	return count
end

return WorldBuilder
