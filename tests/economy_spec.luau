return function(t)
	local Economy = t.Loader.require("src/shared/Economy")
	local Schema = t.Loader.require("src/shared/Schema")
	local Jobs = t.Loader.require("src/shared/Config/Jobs")
	local Prog = t.Loader.require("src/shared/Config/Progression")
	local NOW = 1_700_000_000

	t.suite("Economy", function()
		t.test("new player owns starter vehicle, no cash", function()
			local p = Schema.default(NOW)
			t.eq(p.cash, 0)
			t.truthy(p.ownedVehicles.pebble)
		end)

		t.test("first courier run pays double, then freshness decays", function()
			local p = Schema.default(NOW)
			local raw = Economy.courierRaw(p, Jobs.Jobs.courier.timeLimit, Jobs.Jobs.courier.timeLimit)
			t.eq(raw, Jobs.Courier.baseCash, "full time left pays base")
			local cash1 = Economy.applyJobResult(p, "courier", { success = true, cash = raw, rep = 16 }, NOW)
			t.eq(cash1, raw * 2, "first run 2x")
			t.eq(p.freshness.courier, 1 - Jobs.Freshness.decayOnComplete)
			local cash2 = Economy.applyJobResult(p, "courier", { success = true, cash = raw, rep = 16 }, NOW + 100)
			t.eq(cash2, math.floor(raw * (1 - Jobs.Freshness.decayOnComplete) + 0.5))
			t.eq(p.cash, cash1 + cash2)
		end)

		t.test("freshness never drops below floor and recovers via other jobs", function()
			local p = Schema.default(NOW)
			for i = 1, 20 do
				Economy.applyJobResult(p, "courier", { success = true, cash = 100, rep = 1 }, NOW + i * 100)
			end
			t.eq(p.freshness.courier, Jobs.Freshness.floor)
			Economy.applyJobResult(p, "race", { success = true, cash = 100, rep = 1 }, NOW + 5000)
			t.eq(p.freshness.courier, Jobs.Freshness.floor + Jobs.Freshness.recoverOnOtherJob)
		end)

		t.test("late courier pays nothing", function()
			local p = Schema.default(NOW)
			local cash, rep = Economy.courierRaw(p, 0, 210)
			t.eq(cash, 0)
			t.eq(rep, 0)
		end)

		t.test("reward capped at job maxCash", function()
			local p = Schema.default(NOW)
			local cash = Economy.applyJobResult(p, "heist", { success = true, cash = 1e9, rep = 1 }, NOW)
			t.eq(cash, Jobs.Jobs.heist.maxCash)
		end)

		t.test("failed / abandoned jobs pay no cash and set cooldowns", function()
			local p = Schema.default(NOW)
			local cash = Economy.applyJobResult(p, "heist", { success = false, abandoned = true, cash = 5000, rep = 0 }, NOW)
			t.eq(cash, 0)
			t.eq(p.cooldowns.heist, NOW + Jobs.Jobs.heist.abandonCooldown)
			t.eq(p.firstRunDone.heist, nil, "first-run bonus kept after fail")
		end)

		t.test("heist gated by rep level and cooldown", function()
			local p = Schema.default(NOW)
			local ok = Economy.canStartJob(p, "heist", NOW, false)
			t.eq(ok, false)
			p.rep = Prog.RepLevels[3]
			t.eq((Economy.canStartJob(p, "heist", NOW, false)), true)
			p.cooldowns.heist = NOW + 10
			t.eq((Economy.canStartJob(p, "heist", NOW, false)), false)
			t.eq((Economy.canStartJob(p, "heist", NOW + 10, false)), true)
		end)

		t.test("race requires a vehicle; unknown job rejected", function()
			local p = Schema.default(NOW)
			t.eq((Economy.canStartJob(p, "race", NOW, false)), false)
			t.eq((Economy.canStartJob(p, "race", NOW, true)), true)
			t.eq((Economy.canStartJob(p, "nope", NOW, true)), false)
		end)

		t.test("race medals by time", function()
			t.eq(Economy.raceMedal(90).id, "gold")
			t.eq(Economy.raceMedal(110).id, "silver")
			t.eq(Economy.raceMedal(150).id, "bronze")
			t.eq(Economy.raceMedal(200).id, "finish")
		end)

		t.test("vehicle purchase checks cash, rep, ownership", function()
			local p = Schema.default(NOW)
			t.eq((Economy.buyVehicle(p, "tern")), false, "no cash")
			p.cash = 1500
			t.eq((Economy.buyVehicle(p, "tern")), false, "rep too low")
			p.rep = 100
			t.eq((Economy.buyVehicle(p, "tern")), true)
			t.eq(p.cash, 0)
			t.truthy(p.ownedVehicles.tern)
			p.cash = 99999
			t.eq((Economy.buyVehicle(p, "tern")), false, "already owned")
			t.eq((Economy.buyVehicle(p, "pebble")), false, "starter owned")
			t.eq((Economy.buyVehicle(p, "ghost")), false, "unknown id")
			t.eq(p.cash, 99999, "failed buys spend nothing")
		end)

		t.test("business upgrade, accrual to cap, collect", function()
			local p = Schema.default(NOW)
			p.cash = 500
			t.eq((Economy.upgradeBusiness(p)), true)
			t.eq(p.cash, 0)
			t.eq(p.business.level, 1)
			local carry = 0
			for _ = 1, 30 do
				carry = Economy.tickBusiness(p, 30, carry) -- 15 minutes
			end
			t.eq(p.business.stash, 180) -- 12/min * 15
			for _ = 1, 100 do
				carry = Economy.tickBusiness(p, 60, carry)
			end
			t.eq(p.business.stash, Prog.Business.levels[1].stashCap, "capped")
			t.eq(Economy.collectBusiness(p), 200)
			t.eq(p.cash, 200)
			t.eq(p.business.stash, 0)
			p.cash = 1e9
			t.eq((Economy.upgradeBusiness(p)), false, "level 2 needs rep 3")
		end)

		t.test("courier bonus from business", function()
			local p = Schema.default(NOW)
			p.business.level = 4
			local cash = Economy.courierRaw(p, 210, 210)
			t.eq(cash, Jobs.Courier.baseCash * 1.5)
		end)

		t.test("next goal guides a new player to the first courier run, then purchases", function()
			local p = Schema.default(NOW)
			t.eq(Economy.nextGoal(p, NOW).target, "JobBoard")
			p.firstRunDone.courier = true
			p.cash = 600
			local g = Economy.nextGoal(p, NOW)
			t.eq(g.kind, "buy")
			t.truthy(string.find(g.text, "Noodle Cart"))
		end)

		t.test("next goal for a maxed player", function()
			local p = Schema.default(NOW)
			for _, v in Prog.Vehicles do
				p.ownedVehicles[v.id] = true
			end
			p.business.level = #Prog.Business.levels
			p.rep = 999999
			for _, j in Jobs.Order do
				p.firstRunDone[j] = true
			end
			t.eq(Economy.nextGoal(p, NOW).kind, "done")
		end)
	end)
end
