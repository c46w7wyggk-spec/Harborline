--!strict
-- Windowed movement plausibility check. Pure (time and positions are injected).
--
-- Compares how far a player moved over the last `window` seconds with how far their fastest
-- legitimate mode of travel in that window (on foot / the car they drive) could take them.
-- Measuring over a window, not per tick, means a laggy phone whose position freezes and then
-- catches up is not mistaken for a teleport; and a cheater can't hide by taking small steps.

local MovementGuard = {}
MovementGuard.__index = MovementGuard

MovementGuard.TOLERANCE = 1.3 -- allowed speed = cap * TOLERANCE
MovementGuard.SLACK = 20 -- studs, for respawn nudges, seat snaps, collisions
MovementGuard.MIN_SPAN = 0.5 -- seconds of history needed before judging

export type Verdict = "ok" | "suspect" | "teleport"

function MovementGuard.new(window: number?)
	return setmetatable({ window = window or 2, samples = {} :: { { t: number, x: number, z: number, cap: number } } }, MovementGuard)
end

function MovementGuard:reset()
	table.clear(self.samples)
end

-- cap: fastest legitimate speed (studs/s) for the player's current mode of travel.
function MovementGuard:sample(t: number, x: number, z: number, cap: number): Verdict
	local samples = self.samples
	table.insert(samples, { t = t, x = x, z = z, cap = cap })
	while #samples > 2 and t - samples[2].t >= self.window do
		table.remove(samples, 1)
	end
	local first = samples[1]
	local span = t - first.t
	if span < MovementGuard.MIN_SPAN then
		return "ok"
	end
	local maxCap = 0
	for _, s in samples do
		maxCap = math.max(maxCap, s.cap)
	end
	local dx, dz = x - first.x, z - first.z
	local moved = math.sqrt(dx * dx + dz * dz)
	local allowed = maxCap * MovementGuard.TOLERANCE * span + MovementGuard.SLACK
	if moved <= allowed then
		return "ok"
	end
	self:reset() -- count each event once
	if moved > allowed * 3 + 100 then
		return "teleport"
	end
	return "suspect"
end

return MovementGuard
