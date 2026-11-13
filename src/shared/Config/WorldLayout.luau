--!strict
-- Single source of truth for named locations in the Harborline district.
-- Points are plain {x, z} tables (ground level is y = 0) so this module stays pure and testable.
-- Both WorldBuilder (visuals) and the job modules (server checks) read from here.

export type Point = { x: number, z: number }

local Layout = {}

Layout.MAP_HALF = 800 -- district spans -800..800 studs on X and Z
Layout.BLOCK = 200 -- road grid spacing
Layout.ROAD_WIDTH = 44
Layout.WATER_Z = 760 -- harbor water begins south of this line

local function p(x: number, z: number): Point
	return { x = x, z = z }
end

Layout.Spawn = p(0, -10) -- safe hub plaza centre
Layout.SafeZoneRadius = 70 -- no job pickups/drops inside; jobs can't start you in danger

Layout.Places = {
	JobBoard = p(0, 34), -- start any job here
	CarLot = p(70, -60), -- dealership: buy vehicles
	VehiclePad = p(100, -100), -- personal vehicle spawn
	Depot = p(-400, -8), -- Courier Run parcel pickup
	NoodleStand = p(-70, 60), -- business / property
	OldMint = p(300, -300), -- Vault Job target (fictional mint museum, block centre)
	MintVault = p(300, -320), -- crack point inside the mint courtyard
	Warehouse = p(-700, 500), -- Vault Job drop-off (dockside warehouse yard)
	RaceStart = p(0, 700),
}

-- Delivery addresses (curb-side drop points). Courier Run picks 3 of these.
Layout.Addresses = {
	{ id = "lighthouse_cafe", name = "Lighthouse Cafe", pos = p(610, 610) },
	{ id = "pier_market", name = "Pier 9 Market", pos = p(210, 700) },
	{ id = "kite_shop", name = "Kite & Kettle", pos = p(-210, 420) },
	{ id = "arcade", name = "Pixel Palace Arcade", pos = p(-610, 210) },
	{ id = "laundromat", name = "Spin Cycle Laundry", pos = p(-610, -410) },
	{ id = "radio_tower", name = "KHRB Radio", pos = p(-210, -610) },
	{ id = "bike_works", name = "Gearhead Bike Works", pos = p(210, -210) },
	{ id = "flower_stall", name = "Petal Point", pos = p(610, 10) },
	{ id = "library", name = "Harbor Library", pos = p(410, 210) },
	{ id = "bakery", name = "Rise & Shine Bakery", pos = p(-410, -210) },
}

-- Harbor Sprint: ordered checkpoints, a loop around the district starting and ending at RaceStart.
-- Route: Harbor Boulevard (z = 700) east, down the east edge road, along the north edge, up the west edge.
Layout.HARBOR_BLVD_Z = 700
Layout.RaceCheckpoints = {
	p(400, 700),
	p(800, 400),
	p(800, -400),
	p(400, -800),
	p(-400, -800),
	p(-800, -400),
	p(-800, 400),
	p(-400, 700),
	p(0, 700), -- finish (= start)
}
Layout.CheckpointRadius = 26

-- District landmarks used by WorldBuilder for colourful "memorable" set pieces.
Layout.Landmarks = {
	{ id = "lighthouse", pos = p(720, 800), kind = "Lighthouse" },
	{ id = "ferris", pos = p(300, 300), kind = "Wheel" },
	{ id = "clock", pos = p(-100, -100), kind = "ClockTower" },
}

function Layout.distance(a: Point, b: Point): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

function Layout.addressById(id: string): any
	for _, a in Layout.Addresses do
		if a.id == id then
			return a
		end
	end
	return nil
end

return Layout
