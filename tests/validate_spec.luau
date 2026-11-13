return function(t)
	local Validate = t.Loader.require("src/shared/Validate")
	local RateLimiter = t.Loader.require("src/shared/RateLimiter")
	local MovementGuard = t.Loader.require("src/shared/MovementGuard")

	t.suite("Validate", function()
		t.test("ids", function()
			t.truthy(Validate.id("courier"))
			t.truthy(not Validate.id(""))
			t.truthy(not Validate.id(string.rep("a", 33)))
			t.truthy(not Validate.id("a b"))
			t.truthy(not Validate.id("../x"))
			t.truthy(not Validate.id(5))
			t.truthy(not Validate.id({}))
			t.truthy(not Validate.id(nil))
		end)
		t.test("requests", function()
			t.truthy((Validate.request("StartJob", "race")))
			t.truthy((Validate.request("CancelJob", nil)))
			t.truthy(not (Validate.request("StartJob", { "race" })))
			t.truthy(not (Validate.request("StartJob", 0 / 0)))
			t.truthy(not (Validate.request(nil, nil)))
			t.truthy(not (Validate.request("Start Job", nil)))
		end)
		t.test("knownId", function()
			local set = { a = true }
			t.eq(Validate.knownId("a", set), "a")
			t.eq(Validate.knownId("b", set), nil)
			t.eq(Validate.knownId("__index", set), nil)
		end)
		t.test("finite", function()
			t.truthy(Validate.finite(1))
			t.truthy(not Validate.finite(0 / 0))
			t.truthy(not Validate.finite(math.huge))
			t.truthy(not Validate.finite("1"))
		end)
	end)

	t.suite("RateLimiter", function()
		t.test("burst then refill", function()
			local rl = RateLimiter.new(3, 1)
			t.truthy(rl:allow("p", 0))
			t.truthy(rl:allow("p", 0))
			t.truthy(rl:allow("p", 0))
			t.truthy(not rl:allow("p", 0), "4th in burst blocked")
			t.truthy(not rl:allow("p", 0.5))
			t.truthy(rl:allow("p", 1.6), "refilled")
			t.truthy(rl:allow("other", 0), "keys independent")
		end)
		t.test("clock going backwards does not mint tokens", function()
			local rl = RateLimiter.new(1, 1)
			t.truthy(rl:allow("p", 100))
			t.truthy(not rl:allow("p", 50))
		end)
	end)
	t.suite("MovementGuard", function()
		t.test("steady driving at max speed is ok", function()
			local g = MovementGuard.new(2)
			for i = 0, 100 do
				t.eq(g:sample(i * 0.1, i * 0.1 * 95, 0, 95), "ok")
			end
		end)
		t.test("lag spike (frozen 0.6 s then catch-up) is ok", function()
			local g = MovementGuard.new(2)
			local x = 0
			for i = 0, 30 do
				local tm = i * 0.1
				if i < 10 or i >= 16 then
					x = tm * 95 -- frozen between 1.0 and 1.5 s, then jumps to where it should be
				end
				t.eq(g:sample(tm, x, 0, 95), "ok", "tick " .. i)
			end
		end)
		t.test("small repeated steps faster than the car are caught", function()
			local g = MovementGuard.new(2)
			local verdicts = {}
			for i = 0, 40 do
				verdicts[g:sample(i * 0.1, i * 24, 0, 50)] = true -- 240 studs/s in a 50 studs/s car
			end
			t.truthy(verdicts.suspect or verdicts.teleport)
		end)
		t.test("teleport across the map is a teleport", function()
			local g = MovementGuard.new(2)
			for i = 0, 9 do
				g:sample(i * 0.1, 0, 0, 40)
			end
			t.eq(g:sample(1.0, 900, 900, 40), "teleport")
		end)
		t.test("on foot after leaving a fast car is ok", function()
			local g = MovementGuard.new(2)
			for i = 0, 10 do
				g:sample(i * 0.1, i * 9.5, 0, 95)
			end
			-- car stops dead when you exit; cap drops to on-foot but window remembers the car
			t.eq(g:sample(1.2, 100, 0, 40), "ok")
		end)
	end)
end
