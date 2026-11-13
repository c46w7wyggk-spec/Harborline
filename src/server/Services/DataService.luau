--!strict
-- Session-locked player persistence.
--
-- Record layout in the DataStore (one key per player, "p_<userId>"):
--   { data = Profile, lock = { server = <guid>, t = <unix> }?, savedAt = <unix> }
--
-- Guarantees (within what Roblox DataStores allow):
--  * A profile is only saved by the server that holds its lock, so a stale server can never
--    overwrite newer progress (prevents rejoin/server-hop duplication).
--  * Data that fails to load is never replaced by defaults on a live server: the player is kicked
--    with a "nothing was lost" message instead.
--  * Saves made by a newer schema version are refused rather than downgraded.
--  * Studio uses a separate store name, and falls back to unsaved in-memory play when API access is off.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Schema = require(ReplicatedStorage.Shared.Schema)

local IS_STUDIO = RunService:IsStudio()
local STORE_NAME = "HarborlinePlayers_v1" .. (if IS_STUDIO then "_STUDIO" else "")
local SERVER_ID = HttpService:GenerateGUID(false)
local LOCK_STALE_SECONDS = 90 -- autosave refreshes the lock every AUTOSAVE_SECONDS
local AUTOSAVE_SECONDS = 60
local URGENT_SAVE_MIN_GAP = 8 -- stay under the per-key write limit
local LOAD_ATTEMPTS = 8 -- with backoff this waits ~100 s, longer than a stale lock lasts

export type Session = {
	player: Player,
	key: string,
	token: string, -- this session's lock token (a server can host the same player twice)
	data: Schema.Profile,
	canSave: boolean, -- false in Studio memory mode or after losing the lock
	lastSave: number,
	dirty: boolean,
	saving: boolean,
	releasing: boolean,
	released: boolean,
}

local DataService = {}
DataService.memoryMode = false
DataService.stats = { loads = 0, loadFailures = 0, saves = 0, saveFailures = 0, lockConflicts = 0 }

local sessions: { [Player]: Session } = {}
local loadedCallbacks: { (Player, Session) -> () } = {}
local store: DataStore? = nil

local function log(kind: string, userId: number, detail: any)
	-- Only the numeric user id is logged; no names or message contents.
	warn(string.format("[Data] %s user=%d %s", kind, userId, tostring(detail)))
end

local function isStudioAccessError(err: any): boolean
	local s = tostring(err)
	return string.find(s, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(s, "not allowed to access", 1, true) ~= nil
		or string.find(s, "Studio", 1, true) ~= nil and string.find(s, "API", 1, true) ~= nil
end

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		return store
	end
	return nil
end

local shutdownCallbacks: { () -> () } = {}

-- Runs at the start of BindToClose, before the final saves (e.g. to void active jobs).
function DataService.onShutdown(cb: () -> ())
	table.insert(shutdownCallbacks, cb)
end

function DataService.onLoaded(cb: (Player, Session) -> ())
	table.insert(loadedCallbacks, cb)
end

function DataService.get(player: Player): Session?
	return sessions[player]
end

function DataService.profile(player: Player): Schema.Profile?
	local s = sessions[player]
	return s and s.data
end

-- Drop our lock without changing data (used when we loaded but must not keep the profile).
local function releaseLockOnly(key: string)
	local ds = getStore()
	if not ds then
		return
	end
	pcall(function()
		(ds :: DataStore):UpdateAsync(key, function(old: any)
			if type(old) == "table" and type(old.lock) == "table" and old.lock.server == SERVER_ID then
				old.lock = nil
				return old
			end
			return nil
		end)
	end)
end

local function finishLoad(player: Player, data: Schema.Profile, canSave: boolean, token: string)
	if player.Parent ~= Players then
		-- Player left while we were loading: give the lock back so their next server loads quickly.
		if canSave then
			releaseLockOnly("p_" .. player.UserId)
		end
		return
	end
	local session: Session = {
		player = player,
		key = "p_" .. player.UserId,
		token = token,
		data = data,
		canSave = canSave,
		lastSave = os.clock(),
		dirty = false,
		saving = false,
		releasing = false,
		released = false,
	}
	sessions[player] = session
	DataService.stats.loads += 1
	for _, cb in loadedCallbacks do
		task.spawn(cb, player, session)
	end
end

-- userIds whose leave-save is still in flight on this server. A quick rejoin to the *same*
-- server must wait for it, otherwise it would load the pre-leave copy (our own lock looks valid).
local releasing: { [number]: boolean } = {}

local function load(player: Player)
	local waitUntil = os.clock() + 30
	while releasing[player.UserId] and os.clock() < waitUntil do
		task.wait(0.25)
	end
	local now = os.time()
	local ds = getStore()
	if DataService.memoryMode or not ds then
		if IS_STUDIO then
			DataService.memoryMode = true
			finishLoad(player, Schema.default(now), false, "memory")
		else
			player:Kick("Harborline couldn't reach its save service. Nothing was lost - please rejoin in a minute.")
		end
		return
	end

	local key = "p_" .. player.UserId
	local token = HttpService:GenerateGUID(false)
	for attempt = 1, LOAD_ATTEMPTS do
		if player.Parent ~= Players then
			return
		end
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return (ds :: DataStore):UpdateAsync(key, function(old: any)
				lockedElsewhere = false
				local t = os.time()
				if type(old) == "table" and type(old.lock) == "table" then
					local lock = old.lock
					if lock.server ~= SERVER_ID and type(lock.t) == "number" and t - lock.t < LOCK_STALE_SECONDS then
						lockedElsewhere = true
						return nil -- cancel: another server still owns this profile
					end
				end
				local record = if type(old) == "table" then old else {}
				record.lock = { server = SERVER_ID, session = token, t = t }
				return record
			end)
		end)

		if ok and not lockedElsewhere then
			local record = result
			local raw = if type(record) == "table" then record.data else nil
			if raw == nil then
				finishLoad(player, Schema.default(now), true, token)
				return
			end
			local migrated, why = Schema.migrate(raw)
			if migrated == nil and why == "corrupt" then
				-- Unreadable record: keep a copy for investigation, then start fresh rather than lock the player out.
				log("corrupt-save", player.UserId, typeof(raw))
				pcall(function()
					(ds :: DataStore):SetAsync(key .. "_corrupt_" .. os.time(), { data = raw })
				end)
				finishLoad(player, Schema.default(now), true, token)
				return
			end
			if migrated == nil then
				-- Written by a newer build: don't touch it. Release our lock without changing data.
				log("newer-schema", player.UserId, raw and raw.schema)
				releaseLockOnly(key)
				player:Kick("This server is running an older version of Harborline. Please rejoin.")
				return
			end
			finishLoad(player, Schema.sanitize(migrated, now), true, token)
			return
		end

		if not ok and IS_STUDIO and isStudioAccessError(result) then
			warn("[Data] Studio API access is off: running in memory, progress will NOT be saved.")
			DataService.memoryMode = true
			finishLoad(player, Schema.default(now), false, "memory")
			return
		end

		if lockedElsewhere then
			DataService.stats.lockConflicts += 1
			log("lock-held", player.UserId, "attempt " .. attempt)
		else
			log("load-error", player.UserId, result)
		end
		task.wait(math.min(2 ^ attempt, 15))
	end

	DataService.stats.loadFailures += 1
	if player.Parent == Players then
		player:Kick("Your Harborline save is still syncing from another server. Nothing was lost - rejoin in a minute.")
	end
end

-- Write the session to the DataStore. `release` drops the session lock (player leaving).
local function save(session: Session, release: boolean): boolean
	if not session.canSave or session.released then
		return true
	end
	local ds = getStore()
	if not ds then
		return false
	end
	while session.saving do
		task.wait(0.1)
	end
	-- re-check: the save we waited for may have been the leave-save
	if session.released or not session.canSave or (not release and session.releasing) then
		return true
	end
	session.saving = true
	local userId = session.player.UserId
	local lostLock = false
	local success = false
	for attempt = 1, 3 do
		lostLock = false
		local ok, err = pcall(function()
			(ds :: DataStore):UpdateAsync(session.key, function(old: any)
				lostLock = false
				local lock = if type(old) == "table" then old.lock else nil
				if type(lock) == "table" and (lock.server ~= SERVER_ID or (lock.session ~= nil and lock.session ~= session.token)) then
					lostLock = true
					return nil -- someone else owns this profile now; never overwrite their data
				end
				local t = os.time()
				return {
					data = session.data,
					lock = if release then nil else { server = SERVER_ID, session = session.token, t = t },
					savedAt = t,
				}
			end)
		end)
		if ok then
			success = not lostLock
			break
		end
		log("save-error", userId, err)
		task.wait(2 ^ attempt)
	end
	session.saving = false
	session.lastSave = os.clock()
	if success then
		session.dirty = false
		DataService.stats.saves += 1
		if release then
			session.released = true
		end
	else
		DataService.stats.saveFailures += 1
		if lostLock then
			DataService.stats.lockConflicts += 1
			log("lock-lost", userId, "")
			session.canSave = false
			if session.player.Parent == Players then
				session.player:Kick("Your Harborline session moved to another server. Please rejoin.")
			end
		end
	end
	return success
end

-- Mark progress as changed. Urgent changes (payouts, purchases) are saved soon, throttled.
function DataService.markDirty(player: Player, urgent: boolean?)
	local s = sessions[player]
	if not s then
		return
	end
	s.dirty = true
	if urgent and s.canSave then
		local wait = math.max(0, URGENT_SAVE_MIN_GAP - (os.clock() - s.lastSave))
		task.delay(wait, function()
			if sessions[player] == s and s.dirty then
				save(s, false) -- waits for any save in progress
			end
		end)
	end
end

-- Called by Main *after* other services had their PlayerRemoving cleanup (e.g. job abandon).
function DataService.release(player: Player)
	local s = sessions[player]
	if not s then
		return
	end
	releasing[player.UserId] = true
	s.releasing = true
	sessions[player] = nil -- no further autosaves/urgent saves for this session
	save(s, true)
	releasing[player.UserId] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(function(player)
		load(player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, s in sessions do
				-- always refresh the lock, even when nothing changed
				task.spawn(save, s, false)
			end
		end
	end)

	game:BindToClose(function()
		for _, cb in shutdownCallbacks do
			pcall(cb)
		end
		-- Roblox gives ~30 s; save everyone in parallel.
		local pending = 0
		for _, s in sessions do
			pending += 1
			task.spawn(function()
				save(s, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while (pending > 0 or next(releasing) ~= nil) and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

DataService.IS_STUDIO = IS_STUDIO
DataService.STORE_NAME = STORE_NAME

return DataService
