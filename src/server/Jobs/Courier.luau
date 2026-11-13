--!strict
-- Courier Run state machine. Pure: driven by JobService with server-measured position and time.
-- States: pickup -> deliver(1..N) -> success | fail(timeout)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Config.WorldLayout)
local JobsConfig = require(Shared.Config.Jobs)
local Economy = require(Shared.Economy)

local Courier = {}
Courier.__index = Courier

-- Walking pace used to size the time limit (studs/s after road detours). Real walk speed is 16.
local WALK_PACE = 11
local MIN_LIMIT = 90

-- rng(n) returns an integer in [1, n]. startPos is where the player accepted the job.
function Courier.new(profile: any, now: number, rng: (number) -> number, startPos: Layout.Point?)
	local def = JobsConfig.Jobs.courier
	local depot = Layout.Places.Depot
	local pool = table.clone(Layout.Addresses)
	local picked = {}
	if not profile.firstRunDone.courier then
		-- first run: the three addresses nearest the depot, so it's finishable on foot
		table.sort(pool, function(a, b)
			return Layout.distance(a.pos, depot) < Layout.distance(b.pos, depot)
		end)
		for i = 1, JobsConfig.Courier.stops do
			table.insert(picked, pool[i])
		end
	else
		for _ = 1, JobsConfig.Courier.stops do
			local i = rng(#pool)
			table.insert(picked, pool[i])
			table.remove(pool, i)
		end
	end
	-- order stops nearest-next from the depot so the route makes sense
	local stops = {}
	local at = depot
	while #picked > 0 do
		local best, bestD = 1, math.huge
		for i, a in picked do
			local d = Layout.distance(at, a.pos)
			if d < bestD then
				best, bestD = i, d
			end
		end
		local a = table.remove(picked, best)
		table.insert(stops, a)
		at = a.pos
	end
	local routeLen = 0
	at = depot
	for _, a in stops do
		routeLen += Layout.distance(at, a.pos)
		at = a.pos
	end
	local approach = Layout.distance(startPos or Layout.Places.JobBoard, depot)
	local timeLimit = math.clamp((approach + routeLen) / WALK_PACE + 30, MIN_LIMIT, def.timeLimit)
	return setmetatable({
		id = "courier",
		profile = profile,
		startedAt = now,
		timeLimit = timeLimit,
		deadline = now + timeLimit,
		distanceFactor = math.clamp(routeLen / 1600, 0.6, 1.8),
		state = "pickup",
		stops = stops,
		stopIndex = 0,
	}, Courier)
end

function Courier:objective(now: number)
	local timeLeft = math.max(0, self.deadline - now)
	if self.state == "pickup" then
		return { text = "Pick up the parcels at the Depot", target = Layout.Places.Depot, timeLeft = timeLeft }
	end
	local stop = self.stops[self.stopIndex]
	return {
		text = string.format("Deliver to %s (%d/%d)", stop.name, self.stopIndex, #self.stops),
		target = stop.pos,
		timeLeft = timeLeft,
	}
end

-- ctx = { now, pos = {x,z}?, alive, inVehicle }. Returns nil while running, or a result table.
function Courier:update(ctx: any)
	if ctx.now >= self.deadline then
		return { success = false, reason = "Out of time! The parcels were late.", cash = 0, rep = 0 }
	end
	if not ctx.alive or not ctx.pos then
		return nil -- JobService handles death; just wait
	end
	if self.state == "pickup" then
		if Layout.distance(ctx.pos, Layout.Places.Depot) <= JobsConfig.Courier.depotRadius then
			self.state = "deliver"
			self.stopIndex = 1
			return nil, "Parcels loaded! Deliver them fast."
		end
		return nil
	end
	local stop = self.stops[self.stopIndex]
	if Layout.distance(ctx.pos, stop.pos) <= JobsConfig.Courier.stopRadius then
		if self.stopIndex >= #self.stops then
			local timeLeft = self.deadline - ctx.now
			local cash, rep = Economy.courierRaw(self.profile, timeLeft, self.timeLimit, self.distanceFactor)
			return { success = true, cash = cash, rep = rep, reason = "All parcels delivered!" }
		end
		self.stopIndex += 1
		return nil, "Delivered to " .. stop.name .. "!"
	end
	return nil
end


-- Fastest legitimate completion: straight-line path through required points at the top car speed.
function Courier:minimumSeconds(startPos: any): number
	local cap = JobsConfig.MaxPlausibleSpeed
	local pts = { Layout.Places.Depot }
	for _, s in self.stops do
		table.insert(pts, s.pos)
	end
	local len, prev = 0, startPos
	for _, pt in pts do
		len += math.max(0, Layout.distance(prev, pt) - JobsConfig.Courier.stopRadius)
		prev = pt
	end
	return math.max(JobsConfig.Jobs.courier.minSeconds, len / cap)
end

return Courier
