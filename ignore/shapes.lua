local GPS    = require('gps')
local Socket = require('socket')
local UI     = require('ui')
local Util   = require('util')

local multishell = _ENV.multishell
local textutils  = _G.textutils

multishell.setTitle(multishell.getCurrent(), 'Shapes')

local args = { ... }
local turtleId = args[1] or error('Supply turtle ID')
turtleId = tonumber(turtleId)

local levelScript = [[
  requireInjector(getfenv(1))

  local Util  = require('util')

  local s, m = turtle.run(function()
    --turtle.addFeatures('level')
    require('core.turtle.level')
    turtle.setStatus('Leveling')

    if turtle.enableGPS() then
      local pt = Util.shallowCopy(turtle.point)
      local s, m = pcall(function()
        turtle.level(data.startPt, data.endPt, data.firstPt)
      end)

      turtle.pathfind(pt)

      if not s and m then
        error(m)
      end
    end
  end)

  if not s then
    error(m)
  end
]]

local data = Util.readTable('/usr/config/shapes') or { }

local page = UI.Page {
  titleBar   = UI.TitleBar { title = 'Shapes' },
  info       = UI.Window {  x =  5, y =  3, height = 1 },
  startCoord = UI.Button {  x =  2, y =  6, text = 'Start   ', event = 'startCoord' },
  endCoord   = UI.Button {  x =  2, y =  8, text = 'End     ', event = 'endCoord'   },
  supplies   = UI.Button {  x =  2, y = 10, text = 'Supplies', event = 'supplies'   },
  first      = UI.Button {  x =  2, y = 11, text = 'First',    event = 'firstCoord' },
  cancel     = UI.Button {  x =  2, y = -3, text = 'Abort',    event = 'cancel'     },
  begin      = UI.Button {  x = -8, y = -3, text = 'Begin',    event = 'begin'      },
  accelerators = { q = 'quit' },
  notification = UI.Notification(),
  statusBar = UI.StatusBar(),
}

function page.info:draw()
  local function size(a, b)
    return (math.abs(a.x - b.x) + 1) *
           (math.abs(a.y - b.y) + 1) *
           (math.abs(a.z - b.z) + 1)
  end

  self:clear()
  if not data.startPt then
    self:write(1, 1, 'Set starting corner')
  elseif not data.endPt then
    self:write(1, 1, 'Set ending corner')
  else
    self:write(1, 1, 'Blocks: ' .. size(data.startPt, data.endPt))
  end
end

function page:getPoint()
  local pt = GPS.getPoint()
  if not pt then
    self.notification:error('GPS not available')
  end
  return pt
end

function page:runFunction(id, script)
--Util.writeFile('script.tmp', script)
  self.notification:info('Connecting')
  local fn, msg = loadstring(script, 'script')
  if not fn then
    self.notification:error('Error in script')
    --debug(msg)
    return
  end

  local socket = Socket.connect(id, 161)
  if not socket then
    self.notification:error('Unable to connect')
    return
  end
  socket:write({ type = 'script', args = script })
  socket:close()

  self.notification:success('Sent')
end

function page:eventHandler(event)
  if event.type == 'startCoord' then
    data.startPt = self:getPoint()
    if data.startPt then
      self.statusBar:setStatus('starting corner set')
      Util.writeTable('/usr/config/shapes', data)
    end
    self:draw()
  elseif event.type == 'endCoord' then
    data.endPt = self:getPoint()
    if data.endPt then
      self.statusBar:setStatus('ending corner set')
      Util.writeTable('/usr/config/shapes', data)
    end
    self:draw()
  elseif event.type == 'firstCoord' then
    data.firstPt = self:getPoint()
    if data.firstPt then
      self.statusBar:setStatus('first point set')
      Util.writeTable('/usr/config/shapes', data)
    end
    self:draw()
  elseif event.type == 'supplies' then
    data.suppliesPt = self:getPoint()
    if data.suppliesPt then
      self.statusBar:setStatus('supplies location set')
      Util.writeTable('/usr/config/shapes', data)
    end
  elseif event.type == 'begin' then
    if data.startPt and data.endPt then
      local s = 'local data = ' .. textutils.serialize(data) .. levelScript
      self:runFunction(turtleId, s)
    else
      self.notification:error('Corners not set')
    end
    self.statusBar:setStatus('')
  elseif event.type == 'cancel' then
    self:runFunction(turtleId, 'turtle.abort(true)')
    self.statusBar:setStatus('')
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end

UI:setPage(page)
UI:pullEvents()
