-- Unit tests for pure game logic. Run from the repo root:  lune run tests/run
local Loader = require("./loader")
local process = require("@lune/process")

local passed, failed = 0, 0
local currentSuite = ""

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(string.format("FAIL  %s :: %s\n      %s", currentSuite, name, tostring(err)))
	end
end

local function suite(name: string, fn: () -> ())
	currentSuite = name
	fn()
end

local function eq(a, b, msg: string?)
	if a ~= b then
		error(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", tostring(b), tostring(a)), 2)
	end
end

local function truthy(v, msg: string?)
	if not v then
		error(msg or "expected truthy", 2)
	end
end

local ctx = {
	Loader = Loader,
	test = test,
	suite = suite,
	eq = eq,
	truthy = truthy,
}

for _, name in { "economy_spec", "schema_spec", "validate_spec", "jobs_spec" } do
	require("./" .. name)(ctx)
end

print(string.format("\n%d passed, %d failed", passed, failed))
process.exit(if failed > 0 then 1 else 0)
