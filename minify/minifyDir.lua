local fs    = _G.fs
local shell = _ENV.shell

local function recurse(path)
    if fs.isDir(path) then
        for _, v in pairs(fs.listEx(path)) do
            if not v.isReadOnly then
                recurse(fs.combine(path, v.name))
            end
        end
    elseif path:match('%.lua$') and not fs.isReadOnly(path) then
        local sz = fs.getSize(path)
        shell.run('minify.lua minify ' .. path)
        print(string.format('%s : %.2f%%', path, (sz - fs.getSize(path)) / sz * 100))
    end
end

local path = ({ ... })[1] or error('Syntax: minifyDir PATH')

path = fs.combine(path, '')
if not fs.isDir(path) then
    error('Invalid path')
end

recurse(path)
