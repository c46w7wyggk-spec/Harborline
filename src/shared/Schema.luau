--!strict
-- Player profile schema: defaults, migration between versions, and sanitising of loaded data.
-- Pure: no Roblox services, so it can be unit tested under Lune.

local Progression = require(script.Parent.Config.Progression)
local JobsConfig = require(script.Parent.Config.Jobs)

local Schema = {}

Schema.VERSION = 1
Schema.MAX_CASH = 1e12 -- keeps numbers in exact-integer double range

export type Profile = {
	schema: number,
	cash: number,
	rep: number,
	ownedVehicles: { [string]: boolean },
	business: { level: number, stash: number },
	cooldowns: { [string]: number }, -- jobId -> unix time when available again
	freshness: { [string]: number },
	firstRunDone: { [string]: boolean },
	tutorialStep: number,
	stats: { jobsDone: number, earned: number, playSeconds: number },
	createdAt: number,
}

function Schema.default(now: number): Profile
	return {
		schema = Schema.VERSION,
		cash = 0,
		rep = 0,
		ownedVehicles = { [Progression.StarterVehicle] = true },
		business = { level = 0, stash = 0 },
		cooldowns = {},
		freshness = {},
		firstRunDone = {},
		tutorialStep = 1,
		stats = { jobsDone = 0, earned = 0, playSeconds = 0 },
		createdAt = now,
	}
end

local function finiteNumber(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function int(v: any, lo: number, hi: number, default: number): number
	if not finiteNumber(v) then
		return default
	end
	return math.clamp(math.floor(v), lo, hi)
end

local function num(v: any, lo: number, hi: number, default: number): number
	if not finiteNumber(v) then
		return default
	end
	return math.clamp(v, lo, hi)
end

-- Upgrade older saves to the current version. Unknown future versions are returned as nil so the
-- caller can refuse to load (and never overwrite) data written by a newer build.
function Schema.migrate(data: any): any?
	if type(data) ~= "table" then
		return nil
	end
	local version = data.schema
	if version == nil then
		version = 1 -- pre-versioned dev saves
	end
	if type(version) ~= "number" or version > Schema.VERSION then
		return nil
	end
	-- (future) if version < 2 then ... end
	data.schema = Schema.VERSION
	return data
end

-- Coerce any table into a valid Profile. Drops unknown ids, clamps numbers, fills defaults.
function Schema.sanitize(data: any, now: number): Profile
	local d = Schema.default(now)
	if type(data) ~= "table" then
		return d
	end
	d.cash = int(data.cash, 0, Schema.MAX_CASH, 0)
	d.rep = int(data.rep, 0, Schema.MAX_CASH, 0)

	if type(data.ownedVehicles) == "table" then
		for id, owned in data.ownedVehicles do
			if owned == true and Progression.vehicleById(id) then
				d.ownedVehicles[id] = true
			end
		end
	end
	d.ownedVehicles[Progression.StarterVehicle] = true

	if type(data.business) == "table" then
		local level = int(data.business.level, 0, #Progression.Business.levels, 0)
		d.business.level = level
		local cap = if level > 0 then Progression.Business.levels[level].stashCap else 0
		d.business.stash = int(data.business.stash, 0, cap, 0)
	end

	for _, jobId in JobsConfig.Order do
		if type(data.cooldowns) == "table" then
			-- cooldowns more than a day out are corrupt; drop them
			local c = data.cooldowns[jobId]
			if finiteNumber(c) and c > now and c < now + 86400 then
				d.cooldowns[jobId] = math.floor(c)
			end
		end
		if type(data.freshness) == "table" then
			d.freshness[jobId] = num(data.freshness[jobId], JobsConfig.Freshness.floor, 1, 1)
		else
			d.freshness[jobId] = 1
		end
		if type(data.firstRunDone) == "table" and data.firstRunDone[jobId] == true then
			d.firstRunDone[jobId] = true
		end
	end

	d.tutorialStep = int(data.tutorialStep, 1, 99, 1)
	if type(data.stats) == "table" then
		d.stats.jobsDone = int(data.stats.jobsDone, 0, 1e9, 0)
		d.stats.earned = int(data.stats.earned, 0, Schema.MAX_CASH, 0)
		d.stats.playSeconds = int(data.stats.playSeconds, 0, 1e10, 0)
	end
	d.createdAt = int(data.createdAt, 0, 1e11, now)
	return d
end

return Schema
