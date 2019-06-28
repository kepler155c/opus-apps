local Ansi       = require('opus.ansi')
local Event      = require('opus.event')
local Milo       = require('milo')
local UI         = require('opus.ui')

local colors     = _G.colors
local device     = _G.device
local fs         = _G.fs
local os         = _G.os

local DAY = 20 * 60

local context    = Milo:getContext()
local drives     = { }

--[[ Configuration Screen ]]
local template =
[[%sBackup Drive%s

Backup configuration files each minecraft day.
]]

local wizardPage = UI.WizardPage {
	title = 'Backup Drive',
	index = 2,
	backgroundColor = colors.cyan,
	[1] = UI.TextArea {
		x = 2, ex = -2, y = 2, ey = -2,
		value = string.format(template, Ansi.yellow, Ansi.reset),
	},
}

function wizardPage:isValidType(node)
	local m = device[node.name]
	return m and m.type == 'drive' and {
		name = 'Backup Drive',
		value = 'backup',
		category = 'custom',
		help = 'Backup configuration files',
	}
end

function wizardPage:isValidFor(node)
	return node.mtype == 'backup'
end

UI:getPage('nodeWizard').wizard:add({ backupDrive = wizardPage })

local function clearOld(dir, fname)
	local files = { }

	for _, file in pairs(fs.list(dir)) do
		if file:match(fname) then
			table.insert(files, file)
		end
	end
	if #files > 1 then
		table.sort(files, function(a, b)
			return tonumber(a:match('.(%d+)')) > tonumber(b:match('.(%d+)'))
		end)
		while #files > 1 do
			local old = table.remove(files, #files)
			fs.delete(fs.combine(dir, old))
		end
	end
end

local function makeBackup(dir, fname)
	clearOld(dir, fname)
	local source = fs.combine('usr/config', fname)
	local dest = string.format('%s/%s.%d', dir, fname, os.day())
	fs.copy(source, dest)
end

local function backupNode(node)
	local files = {
		'storage',
		'milo.state',
		'machine_crafting.db',
		'recipes.db',
		'resources.db',
	}
	local s, m = pcall(function()
		if not node.adapter.isDiskPresent() then
			_G._syslog('BACKUP error: No media present')
		else
			local dir = node.adapter.getMountPath()
			for _, v in pairs(files) do
				makeBackup(dir, v)
			end
		end
	end)
	if not s and m then
		_G._syslog('BACKUP error:' .. m)
	end
end

--[[ Task ]]--
local BackupTask = {
	name = 'backup',
	priority = 99,
}

function BackupTask:cycle()
	for node in context.storage:filterActive('backup') do
		if not drives[node.name] then
			drives[node.name] = Event.onInterval(DAY, function()
				_G._syslog('BACKUP: started')
				if node.adapter and node.adapter.online then
					backupNode(node)
				end
			end)
		end
	end
end

Milo:registerTask(BackupTask)
