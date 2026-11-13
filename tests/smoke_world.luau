-- Smoke test: runs the real WorldBuilder against @lune/roblox's Instance model, which validates
-- every class name, property name and value type against Roblox's reflection database.
-- Also builds a vehicle model. Run: lune run tests/smoke_world
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")
local Loader = require("./loader")

local game = roblox.Instance.new("DataModel")

-- Methods lune doesn't implement natively.
roblox.implementMethod("CollectionService", "AddTag", function(_self, inst, tag)
	inst:AddTag(tag)
end)
roblox.implementMethod("CollectionService", "GetTagged", function(_self, tag)
	local out = {}
	for _, d in game:GetDescendants() do
		if d:HasTag(tag) then
			table.insert(out, d)
		end
	end
	return out
end)

local fakeSignal = {
	Connect = function()
		return { Disconnect = function() end }
	end,
}
for _, spec in {
	{ "ProximityPrompt", "Triggered" },
	{ "Players", "PlayerAdded" },
	{ "Players", "PlayerRemoving" },
	{ "RunService", "Heartbeat" },
	{ "RunService", "RenderStepped" },
	{ "GuiObject", "Activated" },
	{ "TextButton", "Activated" },
	{ "RemoteEvent", "OnClientEvent" },
} do
	roblox.implementProperty(spec[1], spec[2], function()
		return fakeSignal
	end)
end
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function()
	return fakeSignal
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	return self:FindFirstChild(name) or error("WaitForChild would hang: " .. name)
end)
roblox.implementMethod("UserInputService", "GetLastInputType", function()
	return roblox.Enum.UserInputType.MouseButton1
end)
roblox.implementMethod("GuiService", "IsTenFootInterface", function()
	return false
end)
roblox.implementMethod("ContextActionService", "BindAction", function() end)

-- Minimal Random (deterministic LCG) since lune has no Random global.
local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	return setmetatable({ s = (seed or 1) % 2147483647 }, Random)
end
function Random:NextNumber(): number
	self.s = (self.s * 48271) % 2147483647
	return self.s / 2147483647
end
function Random:NextInteger(a: number, b: number): number
	return a + math.floor(self:NextNumber() * (b - a + 1))
end

Loader.useRoblox(game, {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	PhysicalProperties = roblox.PhysicalProperties,
	Random = Random,
	task = task,
})

local NetStub = { OpenMenu = { FireClient = function() end } }
Loader.stub("src/server/Services/Net", NetStub)
Loader.stub("src/server/Services/DataService", { profile = function() end, get = function() end })

local ok, err = pcall(function()
	local WorldBuilder = Loader.require("src/server/Services/WorldBuilder")
	local parts = WorldBuilder.build()
	assert(parts > 200, "world too small: " .. parts)
	assert(parts < 3000, "world too heavy for mobile: " .. parts)
	local ws = game:GetService("Workspace")
	local hub = ws:FindFirstChild("Harborline")
	assert(hub, "world folder missing")
	assert(hub:FindFirstChild("JobBoard", true), "job board missing")
	assert(hub:FindFirstChild("HubSpawn", true), "spawn missing")
	local prompts = 0
	for _, d in hub:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			prompts += 1
		end
	end
	assert(prompts == 3, "expected 3 prompts, got " .. prompts)
	print("world ok: " .. parts .. " parts, " .. prompts .. " prompts")

	-- Geometry: no gameplay point may sit inside a solid building/wall footprint.
	local Layout = Loader.require("src/shared/Config/WorldLayout")
	local solids = {}
	for _, d in hub:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Size.Y > 3 and d.Transparency < 1 then
			table.insert(solids, d)
		end
	end
	local function blocked(pt, pad)
		for _, b in solids do
			local okCf, cf = pcall(function()
				return b.CFrame
			end)
			local p = if okCf and cf then cf.Position else b.Position
			local sz = b.Size
			local top, bottom = p.Y + sz.Y / 2, p.Y - sz.Y / 2
			if top > 2 and bottom < 5 and math.abs(pt.x - p.X) < sz.X / 2 + pad and math.abs(pt.z - p.Z) < sz.Z / 2 + pad then
				return b
			end
		end
		return nil
	end
	local points = {}
	for name, pt in Layout.Places do
		table.insert(points, { name, pt })
	end
	for _, a in Layout.Addresses do
		table.insert(points, { a.id, a.pos })
	end
	for i, cp in Layout.RaceCheckpoints do
		table.insert(points, { "checkpoint" .. i, cp })
	end
	local bad = {}
	for _, entry in points do
		local hit = blocked(entry[2], 2)
		if hit and not (entry[1] == "JobBoard" or entry[1] == "CarLot" or entry[1] == "NoodleStand") then
			table.insert(bad, entry[1] .. " inside " .. hit:GetFullName())
		end
	end
	assert(#bad == 0, "points inside solids:\n  " .. table.concat(bad, "\n  "))
	print("geometry ok: " .. #points .. " gameplay points clear of solids")

	-- Vehicles: build every car model with the real property schema.
	local Players = game:GetService("Players")
	local _ = Players
	local playerGui = roblox.Instance.new("PlayerGui")
	-- plain table standing in for a Player: only UserId / PlayerGui / Character are used
	local fakePlayer = {
		UserId = 12345,
		Character = nil,
		WaitForChild = function(_, name)
			assert(name == "PlayerGui")
			return playerGui
		end,
	}
	local Progression = Loader.require("src/shared/Config/Progression")
	local VehicleService = Loader.require("src/server/Services/VehicleService")
	for _, def in Progression.Vehicles do
		local car = VehicleService._buildForTest(fakePlayer, def, roblox.CFrame.new(0, 0, 0))
		assert(car.PrimaryPart and car.PrimaryPart:FindFirstChild("Move"), "car missing constraints")
		assert(car:FindFirstChild("Seat"), "car missing seat")
	end
	print("vehicles ok: " .. #Progression.Vehicles .. " models")

	-- Client UI: build the HUD and every menu tab against the real GUI property schema.
	local camera = {
		ViewportSize = roblox.Vector2.new(844, 390), -- phone landscape
		GetPropertyChangedSignal = function()
			return fakeSignal
		end,
	}
	Loader.overrideService("Players", { LocalPlayer = fakePlayer })
	Loader.overrideService("Workspace", { CurrentCamera = camera })
	Loader.overrideService("UserInputService", {
		TouchEnabled = true,
		KeyboardEnabled = false,
		GamepadEnabled = false,
		GetLastInputType = function()
			return roblox.Enum.UserInputType.Touch
		end,
	})
	Loader.overrideService("GuiService", {
		SelectedObject = nil,
		IsTenFootInterface = function()
			return false
		end,
	})
	Loader.overrideService("TweenService", {
		Create = function()
			return { Play = function() end }
		end,
	})
	local remotes = roblox.Instance.new("Folder")
	remotes.Name = "Remotes"
	for _, n in { "State", "Job", "Notify", "OpenMenu" } do
		local r = roblox.Instance.new("RemoteEvent")
		r.Name = n
		r.Parent = remotes
	end
	local req = roblox.Instance.new("RemoteFunction")
	req.Name = "Request"
	req.Parent = remotes
	remotes.Parent = game:GetService("ReplicatedStorage")

	-- the client tree lives under StarterPlayerScripts in the real place; mount it for the loader
	local Store = Loader.require("src/client/Store")
	local HUD = Loader.require("src/client/Controllers/HUD")
	local Menus = Loader.require("src/client/Controllers/Menus")
	local Waypoint = Loader.require("src/client/Controllers/Waypoint")
	HUD.start()
	Menus.start()
	Waypoint.start()

	local Schema = Loader.require("src/shared/Schema")
	local Economy = Loader.require("src/shared/Economy")
	local Tutorial = Loader.require("src/shared/Tutorial")
	local prof = Schema.default(0)
	prof.cash = 2000
	prof.rep = 150
	prof.business.level = 1
	local snapshot = {
		cash = prof.cash, rep = prof.rep, level = 2, levelRep = 100, nextLevelRep = 300,
		owned = { "pebble" },
		business = { level = 1, name = "Noodle Cart", stash = 50, cap = 200, incomePerMin = 12, nextName = "Noodle Stand", nextCost = 4000, nextRepLevel = 3 },
		cooldowns = { courier = 0, race = 0, heist = 0 },
		freshness = { courier = 0.7, race = 1, heist = 1 },
		firstRunDone = { courier = true },
		tutorial = { step = 2, text = Tutorial.STEPS[2].text, target = "JobBoard", total = Tutorial.COUNT },
		goal = Economy.nextGoal(prof, 0),
		memoryMode = true,
	}
	Store.state = snapshot
	Store.emit("state", snapshot)
	for _, tab in { "jobs", "garage", "dealer", "business", "phone" } do
		Menus.open(tab)
	end
	Store.job = { kind = "objective", jobId = "race", name = "Harbor Sprint", objective = { text = "Checkpoint 2/9", target = Layout.RaceCheckpoints[2], timeLeft = 100, elapsed = 20, checkpoints = Layout.RaceCheckpoints, checkpointIndex = 2 } }
	Store.emit("job", Store.job)
	Store.emit("job", { kind = "objective", jobId = "heist", name = "Vault Job", objective = { text = "Go", target = Layout.Places.Warehouse, timeLeft = 10, heat = 0.5 } })
	Store.emit("jobResult", { success = true, cash = 480, rep = 32, medal = "gold", reason = "Finished" })
	Store.emit("jobResult", { success = false, cash = 0, rep = 0, reason = "Out of time" })
	Store.emit("toast", { text = "Hello", kind = "success" })
	task.wait(0.1)
	local guiCount = 0
	for _, d in playerGui:GetDescendants() do
		if d:IsA("GuiObject") then
			guiCount += 1
		end
	end
	assert(guiCount > 40, "UI too small: " .. guiCount)
	print("client UI ok: " .. guiCount .. " gui objects built across HUD + all menu tabs")
end)

if not ok then
	print("SMOKE FAIL: " .. tostring(err))
	process.exit(1)
end
process.exit(0)
