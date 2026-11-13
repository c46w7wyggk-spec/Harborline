-- Minimal Roblox-require shim for Lune: lets pure game modules that use `script.Parent.X` and
-- `game:GetService("ReplicatedStorage").Shared.X` run unchanged outside Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local ROOT = "src"
local MOUNTS = {
	ReplicatedStorage = { Shared = ROOT .. "/shared" },
	ServerScriptService = { Server = ROOT .. "/server" },
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
function fakeGame:GetService(name: string)
	local mount = MOUNTS[name]
	if mount then
		return setmetatable({}, {
			__index = function(_, key)
				return nodeFromPath(mount[key] or error("unknown mount " .. key))
			end,
		})
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
	local env = setmetatable({
		script = node,
		game = fakeGame,
		require = function(target)
			if type(target) == "table" and target.__path then
				return requireNode(target)
			end
			return require(target)
		end,
	}, { __index = _G })
	local chunk = luau.load(source, { debugName = file, environment = env })
	local result = chunk()
	cache[path] = result
	return result
end

function Loader.require(path: string)
	return requireNode(nodeFromPath(path))
end

return Loader
