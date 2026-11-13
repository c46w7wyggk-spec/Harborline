return function(t)
	local Schema = t.Loader.require("src/shared/Schema")
	local NOW = 1_700_000_000

	t.suite("Schema", function()
		t.test("sanitize rejects NaN, infinity, negatives, unknown ids", function()
			local p = Schema.sanitize({
				cash = 0 / 0,
				rep = math.huge,
				ownedVehicles = { nightjar = true, hacked_car = true, tern = "yes" },
				business = { level = 99, stash = -5 },
				cooldowns = { heist = NOW + 1e9, race = NOW + 30, bogus = NOW + 30 },
				freshness = { courier = -3, race = 0 / 0 },
				tutorialStep = "x",
			}, NOW)
			t.eq(p.cash, 0)
			t.eq(p.rep, 0)
			t.truthy(p.ownedVehicles.nightjar)
			t.eq(p.ownedVehicles.hacked_car, nil)
			t.eq(p.ownedVehicles.tern, nil)
			t.truthy(p.ownedVehicles.pebble, "starter always owned")
			t.eq(p.business.level, 4)
			t.eq(p.business.stash, 0)
			t.eq(p.cooldowns.heist, nil, "absurd cooldown dropped")
			t.eq(p.cooldowns.race, NOW + 30)
			t.eq(p.cooldowns.bogus, nil)
			t.eq(p.freshness.courier, 0.35)
			t.eq(p.freshness.race, 1)
			t.eq(p.tutorialStep, 1)
		end)

		t.test("sanitize keeps valid data", function()
			local src = Schema.default(NOW)
			src.cash = 12345
			src.rep = 777
			src.business = { level = 2, stash = 300 }
			src.firstRunDone.courier = true
			local p = Schema.sanitize(src, NOW)
			t.eq(p.cash, 12345)
			t.eq(p.rep, 777)
			t.eq(p.business.level, 2)
			t.eq(p.business.stash, 300)
			t.eq(p.firstRunDone.courier, true)
		end)

		t.test("stash clamped to level cap; fractional cash floored", function()
			local p = Schema.sanitize({ cash = 10.9, business = { level = 1, stash = 99999 } }, NOW)
			t.eq(p.cash, 10)
			t.eq(p.business.stash, 200)
		end)

		t.test("migrate refuses newer schema and non-tables", function()
			t.eq(Schema.migrate({ schema = Schema.VERSION + 1 }), nil)
			t.eq(Schema.migrate("garbage"), nil)
			t.truthy(Schema.migrate({ schema = 1 }))
			t.truthy(Schema.migrate({}), "unversioned treated as v1")
		end)
	end)
end
