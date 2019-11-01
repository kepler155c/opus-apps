local fs = _G.fs

-- add a System setup tab
fs.mount('sys/apps/system/secure.lua', 'linkfs', 'packages/secure/system/secure.lua')
