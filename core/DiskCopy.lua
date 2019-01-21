local Ansi       = require('ansi')
local Event      = require('event')
local UI         = require('ui')
local Util       = require('util')

local colors     = _G.colors
local fs         = _G.fs
local peripheral = _G.peripheral

local drives = { }
peripheral.find('drive', function(n, v)
  if not drives.left then
    drives.left = Util.shallowCopy(v)
    drives.left.name = n
  else
    drives.right = Util.shallowCopy(v)
    drives.right.name = n
  end
end)

if not (drives.left and drives.right) then
  error('Two drives are required')
end

local COPY_LEFT  = 1
local COPY_RIGHT = 2
local directions = {
  [ COPY_LEFT  ] = { text = '-->>' },
  [ COPY_RIGHT ] = { text = '<<--' },
}
local copyDir = COPY_LEFT

local page = UI.Page {
  linfo = UI.Window {
    x = 2, y = 2, ey = 5, width = 18,
  },
  rinfo = UI.Window {
    x = -19, y = 2, ey = 5, width = 18,
  },
  dir = UI.Button {
    x = 17, y = 7, width = 6,
    event = 'change_dir',
  },
  progress = UI.ProgressBar {
    x = 2, ex = -2, y = -4,
    backgroundColor = colors.black,
  },
  copyButton = UI.Button {
    x = -7, y = -2,
    text = 'Copy',
    event = 'copy',
    inactive = true,
  },
  warning = UI.Text {
    x = 2, ex = -9, y = -2,
    textColor = colors.orange,
  },
  notification = UI.Notification { },
}

function page:enable()
  Util.merge(self.dir, directions[copyDir])
  UI.Page.enable(self)
end

local function isValid(drive)
  return drive.isDiskPresent() and drive.getMountPath()
end

local function needsLabel(drive)
  return drive.isDiskPresent() and not drive.getMountPath()
end

function page:drawInfo(drive, textArea)
  local function getLabel()
    return not drive.isDiskPresent() and 'empty' or
    not drive.getMountPath() and 'invalid' or
    drive.getDiskLabel() or 'unlabeled'
  end

  local function getUsed()
    return isValid(drive) and fs.getSize(drive.getMountPath(), true) or 0
  end

  local function getFree()
    return isValid(drive) and fs.getFreeSpace(drive.getMountPath()) or 0
  end

  textArea:setCursorPos(1, 1)
  textArea:print(string.format('Drive: %s%s%s\nLabel: %s%s%s\nUsed:  %s%s%s\nFree:  %s%s%s',
    Ansi.yellow, drive.name, Ansi.reset,
    isValid(drive) and Ansi.yellow or Ansi.orange, getLabel():sub(1, 10), Ansi.reset,
    Ansi.yellow, Util.toBytes(getUsed()), Ansi.reset,
    Ansi.yellow, Util.toBytes(getFree()), Ansi.reset))
end

function page:scan()
  local showWarning = needsLabel(drives.left) or needsLabel(drives.right)
  local valid = isValid(drives.left) and isValid(drives.right)

  self.warning.value = showWarning and 'Computers must be labeled'
  self.copyButton.inactive = not valid

  self:draw()
  self.progress:centeredWrite(1, 'Analyzing Disks..')
  self.progress:sync()

  self:drawInfo(drives.left, self.linfo)
  self:drawInfo(drives.right, self.rinfo)

  self.progress:clear()
end

function page:copy(sdrive, tdrive)
  local totalFiles = 0
  local throttle = Util.throttle()

  local function countFiles(source, target)
    if fs.isDir(source) then
      local list = fs.list(source)
      for _,f in pairs(list) do
        countFiles(fs.combine(source, f), fs.combine(target, f))
      end
    else
      totalFiles = totalFiles + 1
    end
    throttle()
  end

  local copied = 0
  local function rawCopy(source, target)
    if fs.isDir(source) then
      if not fs.exists(target) then
        fs.makeDir(target)
      end
      local list = fs.list(source)
      for _,f in pairs(list) do
        rawCopy(fs.combine(source, f), fs.combine(target, f))
      end

    else
      if fs.exists(target) then
        fs.delete(target)
      end

      fs.copy(source, target)
      copied = copied + 1
      self.progress.value = copied * 100 / totalFiles
      self.progress:draw()
      self.progress:sync()
    end
    throttle()
  end

  self.progress:centeredWrite(1, 'Computing..')
  self.progress:sync()
  countFiles(sdrive.getMountPath(), tdrive.getMountPath())

  self.progress:clear()
  rawCopy(sdrive.getMountPath(), tdrive.getMountPath())
  self.progress:centeredWrite(1, 'Copy Complete', colors.lime, colors.black)
  self.progress:sync()

  self.progress.value = 0
  self.progress:clear()

  self:scan()
end

function page:eventHandler(event)
  if event.type == 'change_dir' then
    copyDir = (copyDir) % 2 + 1
    Util.merge(self.dir, directions[copyDir])
    self.dir:draw()

  elseif event.type == 'copy' then
    if copyDir == COPY_LEFT then
      self:copy(drives.left, drives.right)
    else
      self:copy(drives.right, drives.left)
    end

	else
		return UI.Page.eventHandler(self, event)
	end
	return true
end

Event.on({ 'disk', 'disk_eject' }, function()
  page:scan()
  page:sync()
end)

Event.onTimeout(.2, function()
  page:scan()
  page:sync()
end)

UI:setPage(page)
UI:pullEvents()
