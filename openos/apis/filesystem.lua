local fs = _G.fs

local function get(path)
  local label = fs.getDrive(path)

  if label then
    local proxy = {
      getLabel = function() return label end,
      isReadOnly = function() return fs.isReadOnly(path) end,
      spaceTotal = function() return fs.getSize(path, true) + fs.getFreeSpace(path) end,
      spaceUsed = function() return fs.getSize(path, true) end,
    }
    return proxy, path
  end
end

local function mounts()
  local t = {
    [ fs.getDrive('/') ] = '/'
  }
  for _,path in pairs(fs.list('/')) do
    local label = fs.getDrive(path)
    if not t[label] then
      t[label] = path
    end
  end

  return function()
    local label, path = next(t)
    if label then
      t[label] = nil
      return get(path)
    end
  end
end

local function list(path)
  local set = fs.list(path)
  return function()
    local key, value = next(set)
    set[key or false] = nil
    return value
  end
end

return {
  canonical = function(...) return ... end,
  concat = fs.combine,
  exists = fs.exists,
  get = get,
  isDirectory = fs.isDir,
  isLink = function() return false end,
  list = list,
  mounts = mounts,
  name = fs.getName,
  open = function(n, m) return fs.open(n, m or 'r') end,
  realPath = function(...) return ... end,
  size = fs.getSize,
}
