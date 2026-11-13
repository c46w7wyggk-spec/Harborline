--!strict
-- Token bucket per key. Time is injected so it can be tested deterministically.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: { capacity: number, refillPerSec: number, buckets: { [any]: { tokens: number, t: number } } },
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSec: number): RateLimiter
	return setmetatable({ capacity = capacity, refillPerSec = refillPerSec, buckets = {} }, RateLimiter)
end

function RateLimiter.allow(self: RateLimiter, key: any, now: number): boolean
	local b = self.buckets[key]
	if not b then
		b = { tokens = self.capacity, t = now }
		self.buckets[key] = b
	end
	local elapsed = math.max(0, now - b.t)
	b.tokens = math.min(self.capacity, b.tokens + elapsed * self.refillPerSec)
	b.t = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.forget(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
