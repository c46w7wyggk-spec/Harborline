--!strict
-- Vault Job state machine. Fictional and non-graphic: no weapons, no NPCs, no injuries.
-- States: approach (reach the Old Mint) -> crack (stay at the vault) -> escape (Heat timer) -> success | fail

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Layout = require(Shared.Config.WorldLayout)
local JobsConfig = require(Shared.Config.Jobs)
local Economy = require(Shared.Economy)

local APPROACH_SECONDS = 150

local Heist = {}
Heist.__index = Heist

function Heist.new(profile: any, now: number)
	return setmetatable({
		id = "heist",
		profile = profile,
		startedAt = now,
		state = "approach",
		deadline = now + APPROACH_SECONDS,
		crackProgress = 0,
		lastNow = now,
		escapeStart = nil :: number?,
	}, Heist)
end

function Heist:objective(now: number)
	local h = JobsConfig.Heist
	if self.state == "approach" then
		return { text = "Sneak into the Old Mint's courtyard vault", target = Layout.Places.MintVault, timeLeft = math.max(0, self.deadline - now) }
	elseif self.state == "crack" then
		return {
			text = string.format("Cracking the vault... stay close (%d%%)", math.floor(self.crackProgress / h.crackSeconds * 100)),
			target = Layout.Places.MintVault,
			timeLeft = math.max(0, self.deadline - now),
			progress = self.crackProgress / h.crackSeconds,
		}
	end
	local heat = (now - (self.escapeStart :: number)) / h.heatSeconds
	return {
		text = "Get the loot bag to the Warehouse before Heat maxes out!",
		target = Layout.Places.Warehouse,
		timeLeft = math.max(0, self.deadline - now),
		heat = math.clamp(heat, 0, 1),
	}
end

function Heist:update(ctx: any)
	local h = JobsConfig.Heist
	local dt = math.max(0, ctx.now - self.lastNow)
	self.lastNow = ctx.now
	if ctx.now >= self.deadline then
		if self.state == "escape" then
			return { success = false, reason = "Heat maxed out - you dropped the bag and slipped away.", cash = 0, rep = h.failRep }
		end
		return { success = false, reason = "Too slow - the Mint locked down.", cash = 0, rep = 0 }
	end
	if not ctx.pos or not ctx.alive then
		return nil
	end

	local nearVault = Layout.distance(ctx.pos, Layout.Places.MintVault) <= h.crackRadius
	if self.state == "approach" then
		if nearVault then
			self.state = "crack"
			self.crackProgress = 0
			return nil, "Hold position while the vault opens!"
		end
	elseif self.state == "crack" then
		if nearVault and not ctx.inVehicle then
			self.crackProgress += dt
			if self.crackProgress >= h.crackSeconds then
				self.state = "escape"
				self.escapeStart = ctx.now
				self.deadline = ctx.now + h.heatSeconds
				return nil, "Vault open! Grab the bag and GO!"
			end
		else
			self.crackProgress = math.max(0, self.crackProgress - dt * 2)
		end
	elseif self.state == "escape" then
		if Layout.distance(ctx.pos, Layout.Places.Warehouse) <= h.dropRadius then
			local cash, rep = Economy.heistRaw(self.profile)
			return { success = true, cash = cash, rep = rep, reason = "Loot delivered. Clean getaway!" }
		end
	end
	return nil
end

function Heist:carryingLoot(): boolean
	return self.state == "escape"
end


-- Fastest legitimate completion: straight-line path through required points at the top car speed.
function Heist:minimumSeconds(startPos: any): number
	local h = JobsConfig.Heist
	local cap = JobsConfig.MaxPlausibleSpeed
	local len = math.max(0, Layout.distance(startPos, Layout.Places.MintVault) - h.crackRadius)
		+ math.max(0, Layout.distance(Layout.Places.MintVault, Layout.Places.Warehouse) - h.dropRadius)
	return math.max(JobsConfig.Jobs.heist.minSeconds, h.crackSeconds + len / cap)
end

return Heist
