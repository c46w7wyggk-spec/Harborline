--!strict
-- Vehicles, business levels and Rep levels. Pure data (numbers from docs/ECONOMY.md).

export type VehicleDef = {
	id: string,
	name: string,
	price: number,
	repLevel: number,
	maxSpeed: number, -- studs/s (server clamps at maxSpeed * 1.05)
	accel: number, -- studs/s^2
	turnRate: number, -- radians/s at full steer
	color: { number },
	size: { number }, -- body X, Y, Z
}

local Progression = {}

Progression.Vehicles = {
	{ id = "pebble", name = "Pebble", price = 0, repLevel = 1, maxSpeed = 50, accel = 30, turnRate = 2.2, color = { 255, 196, 61 }, size = { 6, 3, 9 } },
	{ id = "tern", name = "Tern Hatch", price = 1500, repLevel = 2, maxSpeed = 60, accel = 35, turnRate = 2.1, color = { 92, 200, 255 }, size = { 7, 3, 11 } },
	{ id = "ridgeback", name = "Ridgeback", price = 9000, repLevel = 4, maxSpeed = 70, accel = 39, turnRate = 1.9, color = { 120, 200, 110 }, size = { 8, 4.5, 13 } },
	{ id = "vireo", name = "Vireo GT", price = 32000, repLevel = 6, maxSpeed = 82, accel = 45, turnRate = 2.0, color = { 255, 90, 120 }, size = { 7, 2.6, 13 } },
	{ id = "nightjar", name = "Nightjar", price = 95000, repLevel = 8, maxSpeed = 95, accel = 51, turnRate = 2.1, color = { 160, 110, 255 }, size = { 7.5, 2.4, 14 } },
} :: { VehicleDef }

Progression.StarterVehicle = "pebble"
Progression.TopSpeed = 95

function Progression.vehicleById(id: any): VehicleDef?
	if type(id) ~= "string" then
		return nil
	end
	for _, v in Progression.Vehicles do
		if v.id == id then
			return v
		end
	end
	return nil
end

-- Business: level 0 = not owned. Income accrues only while the owner is online and active,
-- and stops at the stash cap, so coming back to collect matters but AFK farming is capped.
export type BusinessLevel = { name: string, cost: number, repLevel: number, incomePerMin: number, stashCap: number, courierBonus: number }
Progression.Business = {
	name = "Noodle Stand",
	levels = {
		{ name = "Noodle Cart", cost = 500, repLevel = 1, incomePerMin = 12, stashCap = 200, courierBonus = 0.10 },
		{ name = "Noodle Stand", cost = 4000, repLevel = 3, incomePerMin = 35, stashCap = 700, courierBonus = 0.20 },
		{ name = "Night Diner", cost = 16000, repLevel = 5, incomePerMin = 80, stashCap = 1800, courierBonus = 0.35 },
		{ name = "Harbor Kitchen", cost = 50000, repLevel = 7, incomePerMin = 160, stashCap = 4000, courierBonus = 0.50 },
	} :: { BusinessLevel },
	activeWindow = 120, -- seconds since last input/job for the stash to keep filling
}

-- Rep needed to reach each level (index = level).
Progression.RepLevels = { 0, 100, 300, 700, 1300, 2200, 3500, 5200, 7500, 10500 }

function Progression.levelForRep(rep: number): number
	local level = 1
	for i, need in Progression.RepLevels do
		if rep >= need then
			level = i
		end
	end
	return level
end

function Progression.repForNextLevel(rep: number): number?
	return Progression.RepLevels[Progression.levelForRep(rep) + 1]
end

return Progression
