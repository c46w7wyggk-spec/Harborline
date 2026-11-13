-- Minimal Roblox-require shim for Lune: lets pure game modules that use `script.Parent.X` and
-- `game:GetService("ReplicatedStorage").Shared.X` run unchanged outside Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOT = "src"
local MOUNTS = {
	ReplicatedStorage = { Shared = ROOT .. "/shared" },
	ServerScriptService = { Server = ROOT .. "/server" },
	-- (client modules use script.Parent requires, so they load by path)
}

local cache = {}
local Loader = {}

-- Index the tree up front: Lune's fs calls yield, which is not allowed inside metamethods.
local dirs, files = {}, {}
local function scan(path: string)
	dirs[path] = true
	for _, name in fs.readDir(path) do
		local child = path .. "/" .. name
		if fs.isDir(child) then
			scan(child)
		else
			files[child] = true
		end
	end
end
scan(ROOT)

local makeNode

local function nodeFromPath(path: string)
	return makeNode(path)
end

function makeNode(path: string)
	local node = { __path = path }
	return setmetatable(node, {
		__index = function(_, key)
			if key == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				return parent and nodeFromPath(parent) or nil
			end
			local child = path .. "/" .. key
			if dirs[child] or files[child .. ".luau"] then
				return nodeFromPath(child)
			end
			error("no child '" .. tostring(key) .. "' under " .. path, 2)
		end,
	})
end

local fakeGame = {}
local realGame = nil -- optional real DataModel (from @lune/roblox) for smoke tests
local extraGlobals = {}
local serviceOverrides = {}

function fakeGame:GetService(name: string)
	if serviceOverrides[name] then
		return serviceOverrides[name]
	end
	local mount = MOUNTS[name]
	if mount and not realGame then
		return setmetatable({}, {
			__index = function(_, key)
				return nodeFromPath(mount[key] or error("unknown mount " .. key))
			end,
		})
	end
	if mount and realGame then
		-- mounted folders resolve to source nodes, everything else to the real service
		local service = realGame:GetService(name)
		return setmetatable({}, {
			__index = function(_, key)
				if mount[key] then
					return nodeFromPath(mount[key])
				end
				local v = (service :: any)[key]
				if type(v) == "function" then
					return function(_, ...)
						return v(service, ...)
					end
				end
				return v
			end,
		})
	end
	if realGame then
		return realGame:GetService(name)
	end
	return {}
end

local function requireNode(node)
	local path = node.__path
	if cache[path] ~= nil then
		return cache[path]
	end
	local file = path .. ".luau"
	if not files[file] then
		file = path .. "/init.luau"
	end
	local source = fs.readFile(file)
	local env = {
		script = node,
		game = fakeGame,
		workspace = if realGame then realGame:GetService("Workspace") else nil,
		require = function(target)
			if type(target) == "table" and target.__path then
				return requireNode(target)
			end
			return require(target)
		end,
	}
	-- copied in directly: lune replaces the environment's metatable when injecting std globals
	for k, v in extraGlobals do
		env[k] = v
	end
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

-- Replace a module with a stub table (e.g. services with Roblox-only side effects).
function Loader.stub(path: string, value: any)
	cache[path] = value
end

-- Use a real @lune/roblox DataModel plus extra globals (Instance, Vector3, ...) for smoke tests.
function Loader.useRoblox(game: any, globals: { [string]: any })
	realGame = game
	extraGlobals = globals
end

-- Replace a service with a plain table (for client-only APIs lune can't provide).
function Loader.overrideService(name: string, value: any)
	serviceOverrides[name] = value
end

function Loader.require(path: string)
	return requireNode(nodeFromPath(path))
end

return Loader
