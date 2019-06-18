local class      = require('class')
local RSAdapter  = require('core.refinedAdapter')
local Peripheral = require('peripheral')
local Util       = require('util')

local MEAdapter = class(RSAdapter)

local DEVICE_TYPE = 'appliedenergistics2:interface'

function MEAdapter:init(args)
	local defaults = {
		name    = 'appliedEnergistics',
		jobList = { },
	}
	Util.merge(self, defaults)
	Util.merge(self, args)

	local controller
	if not self.side then
		controller = Peripheral.getByType(DEVICE_TYPE)
	else
		controller = Peripheral.getBySide(self.side)
	end

	if controller then
		Util.merge(self, controller)
	end
end

function MEAdapter:isValid()
	return self.type == DEVICE_TYPE and not not self.findItems
end

function MEAdapter:clearFinished()
	for _,key in pairs(Util.keys(self.jobList)) do
		local job = self.jobList[key]
		if job.info.status() == 'finished' then
			self.jobList[key] = nil
		end
	end
end

function MEAdapter:isCPUAvailable()
	local cpus = self.getCraftingCPUs() or { }
	local busy = 0

	for _,cpu in pairs(cpus) do
		if cpu.busy then
			busy = busy + 1
		end
	end
	self:clearFinished()
	return busy == Util.size(self.jobList) and busy < #cpus
end

function MEAdapter:craft(item, count)
	if not self:isCPUAvailable() then
		return false
	end

	local detail = self.findItem(item)
	if detail and detail.craft then
		local info = detail.craft(count or 1)
		if info.status() == 'unknown' then
			self.jobList[info.getId()] = {
				name = item.name,
				damage = item.damage,
				nbtHash = item.nbtHash,
				info = info,
			}
			return true
		end
		return false
	end
end

function MEAdapter:isCrafting(item)
	self:clearFinished()
_G._p = self.jobList
	for _,job in pairs(self.jobList) do
		if job.name == item.name and
			 job.damage == item.damage and
			 job.nbtHash == item.nbtHash then
			return true
		end
	end
	return false
end

return MEAdapter
