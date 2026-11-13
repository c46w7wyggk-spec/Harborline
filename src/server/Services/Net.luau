--!strict
-- The only client->server entry point. Every request goes through: type validation,
-- per-player rate limiting, a loaded-profile check, and a whitelisted handler.
--
-- Remotes (ReplicatedStorage.Remotes):
--   Request  RemoteFunction  (action: string, arg: string?) -> (ok: boolean, message: string?)
--   State    RemoteEvent     server->client profile snapshot
--   Job      RemoteEvent     server->client active job objective / result
--   Notify   RemoteEvent     server->client toast {text, kind}
--   OpenMenu RemoteEvent     server->client menu id (from ProximityPrompts)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Validate = require(ReplicatedStorage.Shared.Validate)
local RateLimiter = require(ReplicatedStorage.Shared.RateLimiter)
local DataService = require(script.Parent.DataService)

type Handler = (player: Player, arg: string?) -> (boolean, string?)

local Net = {}
local handlers: { [string]: Handler } = {}
local limiter = RateLimiter.new(8, 4) -- burst 8, then 4 requests/s
local strikes: { [Player]: number } = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function make(className: string, name: string): any
	local r = Instance.new(className)
	r.Name = name
	r.Parent = folder
	return r
end

local Request = make("RemoteFunction", "Request") :: RemoteFunction
Net.State = make("RemoteEvent", "State") :: RemoteEvent
Net.Job = make("RemoteEvent", "Job") :: RemoteEvent
Net.Notify = make("RemoteEvent", "Notify") :: RemoteEvent
Net.OpenMenu = make("RemoteEvent", "OpenMenu") :: RemoteEvent

function Net.on(action: string, handler: Handler)
	assert(Validate.id(action), "bad action name")
	handlers[action] = handler
end

function Net.notify(player: Player, text: string, kind: string?)
	Net.Notify:FireClient(player, { text = text, kind = kind or "info" })
end

local function strike(player: Player, why: string)
	strikes[player] = (strikes[player] or 0) + 1
	if strikes[player] == 50 then
		warn(string.format("[Net] user=%d sent 50 rejected requests (%s)", player.UserId, why))
	end
end

Request.OnServerInvoke = function(player: Player, action: any, arg: any)
	local valid = Validate.request(action, arg)
	if not valid then
		strike(player, "malformed")
		return false, "Invalid request."
	end
	if not limiter:allow(player, os.clock()) then
		strike(player, "rate")
		return false, "Slow down a little!"
	end
	local handler = handlers[action]
	if not handler then
		strike(player, "unknown action")
		return false, "Unknown action."
	end
	if not DataService.get(player) then
		return false, "Still loading your save..."
	end
	local ok, success, message = pcall(handler, player, arg)
	if not ok then
		warn(string.format("[Net] handler %s errored for user=%d: %s", action, player.UserId, tostring(success)))
		return false, "Something went wrong. Try again."
	end
	return success == true, message
end

function Net.start()
	folder.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		limiter:forget(player)
		strikes[player] = nil
	end)
end

return Net
