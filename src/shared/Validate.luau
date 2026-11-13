--!strict
-- Validation for every client-supplied value. Pure.

local Validate = {}

function Validate.finite(v: any): boolean
	return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

-- Short identifier strings only: letters, digits, underscore; max 32 chars.
function Validate.id(v: any): boolean
	return type(v) == "string" and #v > 0 and #v <= 32 and string.match(v, "^[%w_]+$") ~= nil
end

-- Returns the id if it is a key of `set` (a table keyed by id), else nil.
function Validate.knownId(v: any, set: { [string]: any }): string?
	if Validate.id(v) and set[v] ~= nil then
		return v
	end
	return nil
end

-- Action requests are (actionName: string, arg: id-string | nil). Anything else is rejected,
-- which rules out tables, NaN, Instances and oversized strings in one place.
function Validate.request(action: any, arg: any): (boolean, string?)
	if not Validate.id(action) then
		return false, "bad action"
	end
	if arg ~= nil and not Validate.id(arg) then
		return false, "bad argument"
	end
	return true, nil
end

return Validate
