-- Syntax check: compiles every Luau file under src/ with the real Luau compiler.
-- Run: lune run tests/compile_all
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failures = 0
local count = 0
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.sub(name, -5) == ".luau" then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failures += 1
				print("SYNTAX ERROR " .. path .. "\n  " .. tostring(err))
			end
		end
	end
end
walk("src")
print(string.format("compiled %d files, %d errors", count, failures))
process.exit(if failures > 0 then 1 else 0)
