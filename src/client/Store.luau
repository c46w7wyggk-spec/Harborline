--!strict
-- Client-side cache of what the server told us, plus change listeners.
-- Read-only mirror: nothing here is trusted by the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Store = {}
Store.state = nil :: any -- latest State snapshot
Store.job = nil :: any -- latest Job objective message (nil when free roaming)

local listeners: { [string]: { (any) -> () } } = {}

function Store.on(event: string, cb: (any) -> ())
	listeners[event] = listeners[event] or {}
	table.insert(listeners[event], cb)
end

function Store.emit(event: string, payload: any)
	for _, cb in listeners[event] or {} do
		task.spawn(cb, payload)
	end
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = remotes:WaitForChild("Request") :: RemoteFunction

-- Ask the server to do something. Shows the server's message as a toast.
function Store.request(action: string, arg: string?): (boolean, string?)
	local ok, success, message = pcall(function()
		return Request:InvokeServer(action, arg)
	end)
	if not ok then
		Store.emit("toast", { text = "Connection hiccup - try again.", kind = "warn" })
		return false, nil
	end
	if message then
		Store.emit("toast", { text = message, kind = if success then "success" else "warn" })
	end
	return success, message
end

function Store.start()
	local stateEvent = remotes:WaitForChild("State") :: RemoteEvent
	local jobEvent = remotes:WaitForChild("Job") :: RemoteEvent
	local notifyEvent = remotes:WaitForChild("Notify") :: RemoteEvent
	local menuEvent = remotes:WaitForChild("OpenMenu") :: RemoteEvent
	stateEvent.OnClientEvent:Connect(function(snap)
		Store.state = snap
		Store.emit("state", snap)
	end)
	jobEvent.OnClientEvent:Connect(function(msg)
		if msg.kind == "objective" then
			Store.job = msg
			Store.emit("job", msg)
		elseif msg.kind == "result" then
			Store.job = nil
			Store.emit("job", nil)
			Store.emit("jobResult", msg)
		end
	end)
	notifyEvent.OnClientEvent:Connect(function(n)
		Store.emit("toast", n)
	end)
	menuEvent.OnClientEvent:Connect(function(menuId)
		Store.emit("openMenu", menuId)
	end)
	task.spawn(function()
		-- the server pushes state once the save loads; ask again in case we missed it
		while Store.state == nil do
			pcall(function()
				Request:InvokeServer("GetState")
			end)
			task.wait(3)
		end
	end)
end

return Store
