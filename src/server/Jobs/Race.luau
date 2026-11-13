--!strict
-- Harbor Sprint state machine. Pure.
-- States: staging (drive to the start line) -> racing (checkpoints in order) -> success | fail

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Config.WorldLayout)
local JobsConfig = require(Shared.Config.Jobs)
local Economy = require(Shared.Economy)

local STAGING_SECONDS = 120
local OUT_OF_VEHICLE_GRACE = 6

local Race = {}
Race.__index = Race

function Race.new(profile: any, now: number)
	return setmetatable({
		id = "race",
		profile = profile,
		startedAt = now,
		state = "staging",
		stagingDeadline = now + STAGING_SECONDS,
		raceStart = nil :: number?,
		checkpoint = 0,
		outOfVehicleSince = nil :: number?,
	}, Race)
end

function Race:objective(now: number)
	if self.state == "staging" then
		return {
			text = "Drive to the start line on Harbor Boulevard",
			target = Layout.Places.RaceStart,
			timeLeft = math.max(0, self.stagingDeadline - now),
		}
	end
	local cps = Layout.RaceCheckpoints
	local def = JobsConfig.Jobs.race
	local elapsed = now - (self.raceStart :: number)
	return {
		text = string.format("Checkpoint %d/%d", self.checkpoint, #cps),
		target = cps[self.checkpoint],
		timeLeft = math.max(0, def.timeLimit - elapsed),
		elapsed = elapsed,
		checkpoints = cps,
		checkpointIndex = self.checkpoint,
	}
end

function Race:update(ctx: any)
	local def = JobsConfig.Jobs.race
	if self.state == "staging" then
		if ctx.now >= self.stagingDeadline then
			return { success = false, abandoned = true, reason = "You didn't reach the start line in time.", cash = 0, rep = 0 }
		end
		if ctx.pos and ctx.inVehicle and Layout.distance(ctx.pos, Layout.Places.RaceStart) <= Layout.CheckpointRadius then
			self.state = "racing"
			self.raceStart = ctx.now
			self.checkpoint = 1
			return nil, "GO! Hit every checkpoint."
		end
		return nil
	end

	local elapsed = ctx.now - (self.raceStart :: number)
	if elapsed >= def.timeLimit then
		return { success = false, reason = "Time's up! Race not finished.", cash = 0, rep = 0 }
	end
	if not ctx.inVehicle then
		self.outOfVehicleSince = self.outOfVehicleSince or ctx.now
		if ctx.now - (self.outOfVehicleSince :: number) > OUT_OF_VEHICLE_GRACE then
			return { success = false, reason = "You left your vehicle. Race over.", cash = 0, rep = 0 }
		end
	else
		self.outOfVehicleSince = nil
	end
	if not ctx.pos then
		return nil
	end
	local cps = Layout.RaceCheckpoints
	if Layout.distance(ctx.pos, cps[self.checkpoint]) <= Layout.CheckpointRadius then
		if self.checkpoint >= #cps then
			local cash, rep, medal = Economy.raceRaw(elapsed)
			return {
				success = true,
				cash = cash,
				rep = rep,
				medal = medal,
				raceTime = elapsed,
				reason = string.format("Finished in %.1fs - %s!", elapsed, string.upper(medal)),
			}
		end
		self.checkpoint += 1
		return nil, string.format("Checkpoint! %.1fs", elapsed)
	end
	return nil
end

-- The anti-cheat floor applies to the timed part only, not the drive to the start line.
function Race:timedSeconds(now: number): number
	return if self.raceStart then now - self.raceStart else 0
end

-- Timed part only: straight-line lap through every checkpoint at `cap` studs/s.
function Race:minimumSeconds(_startPos: any, cap: number): number
	local cps = Layout.RaceCheckpoints
	local len = math.max(0, Layout.distance(Layout.Places.RaceStart, cps[1]) - Layout.CheckpointRadius)
	for i = 2, #cps do
		len += math.max(0, Layout.distance(cps[i - 1], cps[i]) - 2 * Layout.CheckpointRadius)
	end
	return math.max(JobsConfig.Jobs.race.minSeconds, len / cap)
end

return Race
