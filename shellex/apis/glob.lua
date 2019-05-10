local GtoP = require('shellex.globtopattern')

local Glob = { }

local fs = _G.fs

local function splitpath(path)
	local parts = { }
	for match in string.gmatch(path, "[^/]+") do
		table.insert(parts, match)
	end
	return parts
end

function Glob.matches(path, spec)
	local t = { }
	local ss = splitpath(spec)
	local abs = string.sub(spec, 1, 1) == '/'

	local function dirMatches(dir, i)
		local files = fs.list(dir)
		local s = GtoP.globtopattern(ss[i])

		for _, f in pairs(files) do
			if f:match(s) then
				local fp = fs.combine(dir, f)
				if not ss[i + 1] then
					table.insert(t, '/' .. fp)
				elseif ss[i + 1] and fs.isDir(fp) then
					dirMatches(fp, i + 1)
				end
			end
		end
	end

	path = '/' .. fs.combine('', path) -- normalize

	dirMatches(abs and '' or path, 1)

	if not abs then
		local len = path == '/' and #path + 1 or #path + 2
		for k, v in pairs(t) do
			t[k] = v:sub(len)
		end
	end

	return t
end

return Glob
