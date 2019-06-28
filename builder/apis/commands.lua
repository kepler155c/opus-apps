local Builder   = require('builder.builder')
local Event     = require('opus.event')
local Util      = require('opus.util')

local commands   = _G.commands
local fs         = _G.fs
local os         = _G.os
local read       = _G.read

function Builder:begin()
	local direction = 1
	local last = #self.schematic.blocks
	local throttle = Util.throttle()

	local cx, cy, cz = commands.getBlockPosition()
	if self.loc.x then
		cx, cy, cz = self.loc.rx, self.loc.ry, self.loc.rz
	end

	if self.mode == 'destroy' then
		direction = -1
		last = 1
	end

	for i = self.index, last, direction do
		self.index = i

		local b = self.schematic:getComputedBlock(i)

		if b.id ~= 'minecraft:air' then

			self:logBlock(self.index, b)

			local id = b.id
			if self.mode == 'destroy' then
				id = 'minecraft:air'
			end

			local function placeBlock(bid, dmg, x, y, z)
				local command = table.concat({
					"setblock",
					cx + x + 1,
					cy + y,
					cz + z + 1,
					bid,
					dmg,
				}, ' ')

				commands.execAsync(command)

				local result = { os.pullEvent("task_complete") }
				if not result[4] then
					Util.print(result[5])
					if self.mode ~= 'destroy' then
						read()
					end
				end
			end

			placeBlock(id, b.odmg, b.x, b.y, b.z)

			if b.twoHigh then
				local _, topBlock = self.schematic:findIndexAt(b.x, b.z, b.y + 1, true)
				if topBlock then
					placeBlock(id, topBlock.odmg, b.x, b.y + 1, b.z)
				end
			end

			if self.mode == 'destroy' then
				self:saveProgress(math.max(self.index, 1))
			else
				self:saveProgress(self.index + 1)
			end
		else
			throttle() -- sleep in case there are a large # of skipped blocks
		end
	end

	fs.delete(self.schematic.filename .. '.progress')
	print('Finished')
	Event.exitPullEvents()
end

return Builder
