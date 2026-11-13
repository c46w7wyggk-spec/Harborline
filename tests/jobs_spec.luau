return function(t)
	local Schema = t.Loader.require("src/shared/Schema")
	local Layout = t.Loader.require("src/shared/Config/WorldLayout")
	local JobsConfig = t.Loader.require("src/shared/Config/Jobs")
	local Courier = t.Loader.require("src/server/Jobs/Courier")
	local Race = t.Loader.require("src/server/Jobs/Race")
	local Heist = t.Loader.require("src/server/Jobs/Heist")
	local NOW = 1000

	local function ctx(now, pos, inVehicle)
		return { now = now, pos = pos, alive = true, inVehicle = inVehicle or false }
	end
	local far = { x = 9999, z = 9999 }

	t.suite("Courier", function()
		t.test("picks distinct stops and completes in order", function()
			local p = Schema.default(0)
			local job = Courier.new(p, NOW, function()
				return 1
			end)
			t.eq(#job.stops, 3)
			t.truthy(job.stops[1].id ~= job.stops[2].id)
			-- going to a stop before the depot does nothing
			t.eq(job:update(ctx(NOW + 1, job.stops[1].pos)), nil)
			t.eq(job.state, "pickup")
			job:update(ctx(NOW + 2, Layout.Places.Depot))
			t.eq(job.state, "deliver")
			-- stops out of order don't count
			job:update(ctx(NOW + 3, job.stops[3].pos))
			t.eq(job.stopIndex, 1)
			job:update(ctx(NOW + 10, job.stops[1].pos))
			job:update(ctx(NOW + 20, job.stops[2].pos))
			local result = job:update(ctx(NOW + 30, job.stops[3].pos))
			t.truthy(result and result.success)
			t.truthy(result.cash > 0)
		end)

		t.test("first run is finishable on foot; later runs scale time and pay with distance", function()
			local p = Schema.default(0)
			local job = Courier.new(p, NOW, function()
				return 1
			end, Layout.Places.JobBoard)
			local len = Layout.distance(Layout.Places.JobBoard, Layout.Places.Depot)
			local at = Layout.Places.Depot
			for _, stop in job.stops do
				len += Layout.distance(at, stop.pos)
				at = stop.pos
			end
			-- walking 16 studs/s with a 1.3x road-detour factor must fit in the limit
			t.truthy(len * 1.3 / 16 <= job.timeLimit, string.format("walk %.0fs > limit %.0fs", len * 1.3 / 16, job.timeLimit))
			p.firstRunDone.courier = true
			local far = Courier.new(p, NOW, function(n)
				return n
			end, Layout.Places.JobBoard)
			t.truthy(far.timeLimit <= JobsConfig.Jobs.courier.timeLimit)
			t.truthy(far.distanceFactor >= 0.6 and far.distanceFactor <= 1.8)
		end)

		t.test("times out", function()
			local job = Courier.new(Schema.default(0), NOW, function()
				return 1
			end)
			local r = job:update(ctx(NOW + JobsConfig.Jobs.courier.timeLimit, far))
			t.truthy(r and not r.success)
		end)
	end)

	t.suite("Race", function()
		t.test("needs vehicle at start line, checkpoints in order, medal", function()
			local job = Race.new(Schema.default(0), NOW)
			job:update(ctx(NOW + 1, Layout.Places.RaceStart, false))
			t.eq(job.state, "staging", "on foot doesn't start")
			job:update(ctx(NOW + 2, Layout.Places.RaceStart, true))
			t.eq(job.state, "racing")
			local cps = Layout.RaceCheckpoints
			-- skipping ahead does nothing
			job:update(ctx(NOW + 5, cps[3], true))
			t.eq(job.checkpoint, 1)
			local r
			for i, cp in cps do
				r = job:update(ctx(NOW + 2 + i * 10, cp, true))
			end
			t.truthy(r and r.success)
			t.eq(r.medal, "gold") -- 90s
			t.eq(job:timedSeconds(NOW + 92), 90)
		end)

		t.test("leaving the vehicle fails after grace", function()
			local job = Race.new(Schema.default(0), NOW)
			job:update(ctx(NOW, Layout.Places.RaceStart, true))
			t.eq(job:update(ctx(NOW + 1, far, false)), nil)
			local r = job:update(ctx(NOW + 10, far, false))
			t.truthy(r and not r.success)
		end)
	end)

	t.suite("Heist", function()
		t.test("crack requires staying on foot near the vault", function()
			local job = Heist.new(Schema.default(0), NOW)
			local vault = Layout.Places.MintVault
			job:update(ctx(NOW + 10, vault))
			t.eq(job.state, "crack")
			job:update(ctx(NOW + 12, vault, true)) -- in a car: no progress
			t.eq(job.crackProgress, 0)
			job:update(ctx(NOW + 15, vault))
			t.eq(job.crackProgress, 3)
			job:update(ctx(NOW + 16, far)) -- walked away: progress drains
			t.eq(job.crackProgress, 1)
			job:update(ctx(NOW + 21, vault))
			t.eq(job.state, "escape")
			local r = job:update(ctx(NOW + 60, Layout.Places.Warehouse))
			t.truthy(r and r.success)
			t.eq(r.cash, JobsConfig.Heist.baseCash)
		end)

		t.test("heat timeout fails with small rep", function()
			local job = Heist.new(Schema.default(0), NOW)
			local vault = Layout.Places.MintVault
			job:update(ctx(NOW + 1, vault))
			job:update(ctx(NOW + 10, vault))
			t.eq(job.state, "escape")
			local r = job:update(ctx(NOW + 10 + JobsConfig.Heist.heatSeconds, far))
			t.truthy(r and not r.success)
			t.eq(r.rep, JobsConfig.Heist.failRep)
		end)
	end)

	t.suite("Anti-cheat floors", function()
		t.test("courier/heist floors are below a realistic run and above a teleport", function()
			local job = Courier.new(Schema.default(0), NOW, function()
				return 1
			end)
			local floor = job:minimumSeconds(Layout.Places.JobBoard)
			t.truthy(floor >= JobsConfig.Jobs.courier.minSeconds)
			t.truthy(floor < JobsConfig.Jobs.courier.timeLimit)
			local h = Heist.new(Schema.default(0), NOW)
			local hf = h:minimumSeconds(Layout.Places.JobBoard)
			t.truthy(hf > JobsConfig.Heist.crackSeconds + 10, "heist floor " .. hf)
		end)
	end)

	t.suite("Layout", function()
		t.test("no job point inside the hub safe zone", function()
			for _, a in Layout.Addresses do
				t.truthy(Layout.distance(a.pos, Layout.Spawn) > Layout.SafeZoneRadius, a.id)
			end
			t.truthy(Layout.distance(Layout.Places.MintVault, Layout.Spawn) > Layout.SafeZoneRadius)
		end)
		t.test("race lap length supports the minSeconds floor", function()
			local cps = Layout.RaceCheckpoints
			local len = Layout.distance(Layout.Places.RaceStart, cps[1])
			for i = 2, #cps do
				len += Layout.distance(cps[i - 1], cps[i])
			end
			-- straight-line lap / (top speed * 1.15) must be >= the floor, or legit fast cars get rejected
			t.truthy(len / (95 * 1.15) >= JobsConfig.Jobs.race.minSeconds, "lap " .. len)
		end)
	end)
end
