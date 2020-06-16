local ccemux     = _G.ccemux
local fs         = _G.fs
local textutils  = _G.textutils

if ccemux then
	-- add a System setup tab
	fs.mount('sys/apps/system/ccemux.lua', 'linkfs', 'packages/ccemux/system/ccemux.lua')

	_G.kernel.hook('clipboard_copy', function(_, args)
		local data = args[1]
		if type(data) == 'table' then
			local s, m = pcall(textutils.serialize, data)
			data = s and m or tostring(data)
		end

		if data then
			ccemux.setClipboard(data)
		end
	end)
end
