--!strict
-- All economy rules as pure functions over a Profile. The server is the only caller that mutates
-- real player data; the client may call the read-only helpers for display (prices, next goal).

local Progression = require(script.Parent.Config.Progression)
local JobsConfig = require(script.Parent.Config.Jobs)
local Schema = require(script.Parent.Schema)

type Profile = Schema.Profile

local Economy = {}

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function Economy.level(profile: Profile): number
	return Progression.levelForRep(profile.rep)
end

function Economy.businessLevel(profile: Profile): Progression.BusinessLevel?
	local lvl = profile.business.level
	if lvl <= 0 then
		return nil
	end
	return Progression.Business.levels[lvl]
end

---------------------------------------------------------------------------- job gating

function Economy.canStartJob(profile: Profile, jobId: string, now: number, inVehicle: boolean): (boolean, string?)
	local def = JobsConfig.Jobs[jobId]
	if not def then
		return false, "Unknown job."
	end
	if Economy.level(profile) < def.repLevel then
		return false, string.format("%s unlocks at Rep level %d.", def.name, def.repLevel)
	end
	local readyAt = profile.cooldowns[jobId]
	if readyAt and readyAt > now then
		return false, string.format("%s is cooling down (%ds).", def.name, math.ceil(readyAt - now))
	end
	if def.requiresVehicle and not inVehicle then
		return false, "Hop in a vehicle first (spawn one at the Car Lot pad)."
	end
	return true, nil
end

---------------------------------------------------------------------------- raw rewards

-- Courier: fraction of time left in [0,1]. Late = nothing.
-- distanceFactor scales pay with route length (longer routes pay more).
function Economy.courierRaw(profile: Profile, timeLeft: number, timeLimit: number, distanceFactor: number?): (number, number)
	if timeLeft <= 0 then
		return 0, 0
	end
	local c = JobsConfig.Courier
	local biz = Economy.businessLevel(profile)
	local bonus = if biz then 1 + biz.courierBonus else 1
	local cash = c.baseCash * (distanceFactor or 1) * (0.4 + 0.6 * clamp01(timeLeft / timeLimit)) * bonus
	return cash, c.rep
end

function Economy.raceMedal(finishTime: number): any
	for _, m in JobsConfig.RaceMedals do
		if finishTime <= m.time then
			return m
		end
	end
	return JobsConfig.RaceMedals[#JobsConfig.RaceMedals]
end

function Economy.raceRaw(finishTime: number): (number, number, string)
	local m = Economy.raceMedal(finishTime)
	return m.cash, m.rep, m.id
end

function Economy.heistRaw(profile: Profile): (number, number)
	local h = JobsConfig.Heist
	local above = math.max(0, Economy.level(profile) - 3)
	return h.baseCash * (1 + h.cashPerLevelAbove3 * above), h.rep
end

---------------------------------------------------------------------------- applying results

-- Final reward after freshness, first-run bonus and the per-job cap. Integers.
function Economy.finalReward(profile: Profile, jobId: string, rawCash: number, rawRep: number): (number, number)
	local def = JobsConfig.Jobs[jobId]
	local mult = 1
	if def.usesFreshness then
		mult *= profile.freshness[jobId] or 1
	end
	if not profile.firstRunDone[jobId] then
		mult *= JobsConfig.FirstRunMult
	end
	local cash = math.clamp(math.floor(rawCash * mult + 0.5), 0, def.maxCash)
	if jobId == "courier" and not profile.firstRunDone.courier and rawCash > 0 then
		cash = math.max(cash, JobsConfig.Courier.firstRunMinCash)
	end
	local rep = math.max(0, math.floor(rawRep * (if def.usesFreshness then (profile.freshness[jobId] or 1) else 1) + 0.5))
	return cash, rep
end

export type JobResult = { success: boolean, abandoned: boolean?, cash: number, rep: number }

-- Mutates the profile with a job outcome: money, rep, freshness, cooldown, stats.
-- Returns the cash and rep actually granted.
function Economy.applyJobResult(profile: Profile, jobId: string, result: JobResult, now: number): (number, number)
	local def = JobsConfig.Jobs[jobId]
	local f = JobsConfig.Freshness
	local cash, rep = 0, 0
	if result.success then
		cash, rep = Economy.finalReward(profile, jobId, result.cash, result.rep)
		profile.firstRunDone[jobId] = true
		profile.stats.jobsDone += 1
		-- freshness: this job decays, the others recover
		for _, other in JobsConfig.Order do
			local cur = profile.freshness[other] or 1
			if other == jobId then
				if def.usesFreshness then
					profile.freshness[other] = math.max(f.floor, cur - f.decayOnComplete)
				end
			else
				profile.freshness[other] = math.min(1, cur + f.recoverOnOtherJob)
			end
		end
		profile.cooldowns[jobId] = now + def.cooldown
	else
		rep = math.max(0, math.floor(result.rep))
		profile.cooldowns[jobId] = now + (if result.abandoned then def.abandonCooldown else def.cooldown)
	end
	Economy.addCash(profile, cash)
	profile.rep = math.min(Schema.MAX_CASH, profile.rep + rep)
	return cash, rep
end

function Economy.addCash(profile: Profile, amount: number)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	profile.cash = math.min(Schema.MAX_CASH, profile.cash + amount)
	profile.stats.earned = math.min(Schema.MAX_CASH, profile.stats.earned + amount)
end

function Economy.recoverFreshness(profile: Profile, minutes: number)
	local f = JobsConfig.Freshness
	for _, jobId in JobsConfig.Order do
		profile.freshness[jobId] = math.min(1, (profile.freshness[jobId] or 1) + f.recoverPerMinute * minutes)
	end
end

---------------------------------------------------------------------------- purchases

function Economy.canBuyVehicle(profile: Profile, vehicleId: string): (boolean, string?)
	local v = Progression.vehicleById(vehicleId)
	if not v then
		return false, "Unknown vehicle."
	end
	if profile.ownedVehicles[v.id] then
		return false, "You already own the " .. v.name .. "."
	end
	if Economy.level(profile) < v.repLevel then
		return false, string.format("%s needs Rep level %d.", v.name, v.repLevel)
	end
	if profile.cash < v.price then
		return false, string.format("You need $%d more.", v.price - profile.cash)
	end
	return true, nil
end

function Economy.buyVehicle(profile: Profile, vehicleId: string): (boolean, string?)
	local ok, err = Economy.canBuyVehicle(profile, vehicleId)
	if not ok then
		return false, err
	end
	local v = Progression.vehicleById(vehicleId) :: Progression.VehicleDef
	profile.cash -= v.price
	profile.ownedVehicles[v.id] = true
	return true, nil
end

function Economy.nextBusinessLevel(profile: Profile): Progression.BusinessLevel?
	return Progression.Business.levels[profile.business.level + 1]
end

function Economy.canUpgradeBusiness(profile: Profile): (boolean, string?)
	local nextLvl = Economy.nextBusinessLevel(profile)
	if not nextLvl then
		return false, "Your business is fully upgraded."
	end
	if Economy.level(profile) < nextLvl.repLevel then
		return false, string.format("%s needs Rep level %d.", nextLvl.name, nextLvl.repLevel)
	end
	if profile.cash < nextLvl.cost then
		return false, string.format("You need $%d more.", nextLvl.cost - profile.cash)
	end
	return true, nil
end

function Economy.upgradeBusiness(profile: Profile): (boolean, string?)
	local ok, err = Economy.canUpgradeBusiness(profile)
	if not ok then
		return false, err
	end
	local nextLvl = Economy.nextBusinessLevel(profile) :: Progression.BusinessLevel
	profile.cash -= nextLvl.cost
	profile.business.level += 1
	return true, nil
end

-- Accrue stash for `seconds` of active online time. `carry` is the fractional remainder
-- (kept in memory by the server). Returns the new carry.
function Economy.tickBusiness(profile: Profile, seconds: number, carry: number): number
	local biz = Economy.businessLevel(profile)
	if not biz or seconds <= 0 then
		return 0
	end
	local total = carry + biz.incomePerMin * seconds / 60
	local whole = math.floor(total)
	profile.business.stash = math.min(biz.stashCap, profile.business.stash + whole)
	if profile.business.stash >= biz.stashCap then
		return 0
	end
	return total - whole
end

function Economy.collectBusiness(profile: Profile): number
	local amount = profile.business.stash
	profile.business.stash = 0
	Economy.addCash(profile, amount)
	return amount
end

---------------------------------------------------------------------------- next goal

export type Goal = { kind: string, text: string, target: string?, progress: number? }

-- One recommendation at a time (docs/ECONOMY.md section 8, simplified: no rolling-rate ETA).
function Economy.nextGoal(profile: Profile, now: number): Goal
	local level = Economy.level(profile)
	local biz = Economy.businessLevel(profile)

	if biz and profile.business.stash >= biz.stashCap * 0.8 then
		return { kind = "collect", text = string.format("Collect $%d from your %s", profile.business.stash, biz.name), target = "NoodleStand" }
	end

	if not profile.firstRunDone.courier then
		return { kind = "job", text = "Start a Courier Run at the Job Board (2x pay first time!)", target = "JobBoard" }
	end

	-- cheapest next purchase
	local options = {}
	local nb = Economy.nextBusinessLevel(profile)
	if nb then
		table.insert(options, { kind = "business", name = nb.name, cost = nb.cost, repLevel = nb.repLevel, target = "NoodleStand" })
	end
	for _, v in Progression.Vehicles do
		if not profile.ownedVehicles[v.id] then
			table.insert(options, { kind = "vehicle", name = v.name, cost = v.price, repLevel = v.repLevel, target = "CarLot" })
			break -- only the next tier
		end
	end
	-- affordable now: prefer business
	for _, o in options do
		if profile.cash >= o.cost and level >= o.repLevel then
			return { kind = "buy", text = string.format("Buy the %s ($%d)", o.name, o.cost), target = o.target, progress = 1 }
		end
	end

	if level >= JobsConfig.Jobs.heist.repLevel and not profile.firstRunDone.heist then
		local readyAt = profile.cooldowns.heist
		if not readyAt or readyAt <= now then
			return { kind = "job", text = "Try the Vault Job (2x pay first time!)", target = "JobBoard" }
		end
	end
	if not profile.firstRunDone.race then
		return { kind = "job", text = "Race the Harbor Sprint in a vehicle (2x pay first time!)", target = "JobBoard" }
	end

	-- save up for the cheapest option you meet the Rep for; otherwise the next Rep level
	table.sort(options, function(a, b)
		return a.cost < b.cost
	end)
	for _, o in options do
		if level >= o.repLevel then
			return {
				kind = "save",
				text = string.format("Save $%d for the %s", o.cost, o.name),
				target = o.target,
				progress = clamp01(profile.cash / o.cost),
			}
		end
	end
	local needRep = Progression.repForNextLevel(profile.rep)
	if needRep then
		local prev = Progression.RepLevels[level]
		return {
			kind = "rep",
			text = string.format("Earn Rep to reach level %d (%d/%d)", level + 1, profile.rep, needRep),
			target = "JobBoard",
			progress = clamp01((profile.rep - prev) / (needRep - prev)),
		}
	end
	return { kind = "done", text = "You own Harborline. Chase gold medals!", target = "JobBoard" }
end

return Economy
