local itemDB = require('itemDB')
local Milo   = require('milo')
local UI     = require('ui')
local Util   = require('util')

local colors = _G.colors
local turtle = _G.turtle

local function learnRecipe()
	local ingredients = Milo:getTurtleInventory()

	if not ingredients then
		return false, 'No recipe defined'
	end

	turtle.select(1)
	if not turtle.craft() then
		return false, 'Failed to craft'
	end

	local results = Milo:getTurtleInventory()
	if not results or not results[1] then
		return false, 'Failed to craft'
	end

	local maxCount
	local newRecipe = {
		ingredients = ingredients,
	}

	local numResults = 0
	for _,v in pairs(results) do
		if v.count > 0 then
			numResults = numResults + 1
		end
	end
	if numResults > 1 then
		for _,v1 in pairs(results) do
			for _,v2 in pairs(ingredients) do
				if v1.name == v2.name and
					v1.nbtHash == v2.nbtHash and
					(v1.damage == v2.damage or
						(v1.maxDamage > 0 and v2.maxDamage > 0 and
						 v1.damage ~= v2.damage)) then
					if not newRecipe.crafingTools then
						newRecipe.craftingTools = { }
					end
					local tool = Util.shallowCopy(v2)
					if tool.maxDamage > 0 then
						tool.damage = '*'
					end

					--[[
					Turtles can only craft one item at a time using a tool :(
					]]--
					maxCount = 1

					newRecipe.craftingTools[Milo:uniqueKey(tool)] = true
					v1.craftingTool = true
					break
				end
			end
		end
	end

	local recipe
	for _,v in pairs(results) do
		if not v.craftingTool then
			recipe = v
			if maxCount then
				recipe.maxCount = maxCount
			end
			break
		end
	end

	if not recipe then
		return false, 'Unknown error'
	end

	newRecipe.count = recipe.count

	local key = Milo:uniqueKey(recipe)
	if recipe.maxCount ~= 64 then
		newRecipe.maxCount = recipe.maxCount
	end
	for k,ingredient in pairs(Util.shallowCopy(ingredients)) do
		if ingredient.maxDamage > 0 then
			-- ingredient.damage = '*'               -- I don't think this is right
		end
		ingredients[k] = Milo:uniqueKey(ingredient)
	end

	Milo:updateRecipe(key, newRecipe)
	turtle.emptyInventory()

	return recipe
end

local pages = {
	turtleCraft = UI.Window {
		index = 2,
		validFor = 'Turtle Crafting',
		notice = UI.Text {
			x = 3, y = 2,
			textColor = colors.yellow,
			value = 'Place recipe in turtle',
		},
	},
}

function pages.turtleCraft:validate()
	local recipe, msg = learnRecipe()

	if recipe then
		local displayName = itemDB:getName(recipe)

		UI:setPage('listing', {
			filter = displayName,
			message = 'Learned: ' .. displayName,
		})
		return true
	else
		self:emit({ type = 'general_error', message = msg })
	end
end

UI:getPage('learnWizard').wizard:add(pages)
