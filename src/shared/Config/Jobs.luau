--!strict
-- Tunable job definitions. All rewards are computed on the server from these numbers.
-- Times are seconds. Speeds are studs/second. Numbers follow docs/ECONOMY.md.

export type JobDef = {
	id: string,
	name: string,
	blurb: string,
	timeLimit: number,
	minSeconds: number, -- absolute anti-cheat floor; JobService also applies a per-run path-length floor
	cooldown: number, -- after success or fail, persisted as an absolute unix time
	abandonCooldown: number, -- after cancel / leaving / dying
	repLevel: number, -- Rep level required
	requiresVehicle: boolean,
	usesFreshness: boolean,
	maxCash: number, -- hard cap per completion after every multiplier
}

local Jobs: { [string]: JobDef } = {
	courier = {
		id = "courier",
		name = "Courier Run",
		blurb = "Grab parcels at the Depot and drop them at 3 addresses before time runs out.",
		timeLimit = 210,
		minSeconds = 15,
		cooldown = 5,
		abandonCooldown = 10,
		repLevel = 1,
		requiresVehicle = false,
		usesFreshness = true,
		maxCash = 1200,
	},
	race = {
		id = "race",
		name = "Harbor Sprint",
		blurb = "Solo time trial around the district. Hit every checkpoint in order. Faster medal, bigger prize.",
		timeLimit = 240,
		minSeconds = 45, -- straight-line lap ~5330 studs / (95 top speed * 1.15) = 48.8
		cooldown = 10,
		abandonCooldown = 15,
		repLevel = 1,
		requiresVehicle = true,
		usesFreshness = true,
		maxCash = 1600,
	},
	heist = {
		id = "heist",
		name = "Vault Job",
		blurb = "Crack the Old Mint's prop vault, then rush the loot bag to the Warehouse before the Heat meter fills.",
		timeLimit = 300, -- whole job (reach mint + crack + delivery)
		minSeconds = 15,
		cooldown = 600,
		abandonCooldown = 300,
		repLevel = 3,
		requiresVehicle = false,
		usesFreshness = false, -- the cooldown limits this job
		maxCash = 6000,
	},
}

local Config = {}
Config.Jobs = Jobs
Config.Order = { "courier", "race", "heist" }
Config.FirstRunMult = 2 -- first ever completion of each job pays double

-- Courier Run: three stops, reward = base * (0.4 + 0.6 * timeLeftFraction) * freshness * business bonus.
Config.Courier = {
	stops = 3,
	baseCash = 240,
	rep = 16,
	stopRadius = 24,
	depotRadius = 24,
}

-- Harbor Sprint medals (finish time <= time). DNF after timeLimit pays nothing.
Config.RaceMedals = {
	{ id = "gold", time = 105, cash = 600, rep = 30 },
	{ id = "silver", time = 125, cash = 400, rep = 22 },
	{ id = "bronze", time = 160, cash = 250, rep = 14 },
	{ id = "finish", time = math.huge, cash = 120, rep = 6 },
}

-- Vault Job
Config.Heist = {
	crackSeconds = 5, -- must stay within crackRadius for this long
	crackRadius = 18,
	dropRadius = 28,
	heatSeconds = 150, -- from crack complete to drop-off
	baseCash = 1500,
	cashPerLevelAbove3 = 0.15,
	rep = 50,
	failRep = 5,
}

-- Anti-repetition (see docs/ECONOMY.md section 2).
Config.Freshness = {
	floor = 0.35,
	decayOnComplete = 0.15,
	recoverOnOtherJob = 0.25,
	recoverPerMinute = 0.03,
}

-- Movement sanity: positions sampled at 10 Hz; flag if implied speed exceeds this (top car 95 * 1.15).
Config.MaxPlausibleSpeed = 110
Config.FlagsBeforeKick = 3

return Config
