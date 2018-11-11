local Craft  = require('turtle.craft')
local Milo   = require('milo')
local sync   = require('sync').sync
local Util   = require('util')

local context = Milo:getContext()
local turtle  = _G.turtle

local craftTask = {
  name = 'crafting',
  priority = 70,
}

function craftTask:craft(recipe, item)
  if Milo:isCraftingPaused() then
    return
  end

  -- TODO: refactor into craft.lua
  Craft.processPending(item, context.storage)

  -- create a mini-list of items that are required for this recipe
  item.ingredients = Craft.getResourceList(
    recipe, Milo:listItems(), item.requested - item.crafted, item.pending)

  for k, v in pairs(item.ingredients) do
    v.crafted = v.used
    v.count = v.used
    v.key = k
    if v.need > 0 then
      v.status = 'No recipe'
      v.statusCode = Craft.STATUS_ERROR
    end
  end
  item.ingredients[recipe.result] = item
  item.ingredients[recipe.result].total = item.count
  item.ingredients[recipe.result].crafted = item.crafted

_G._p2 = item
if not item.history then
  item.history = { }
end
local t = Util.shallowCopy(item)
t.history = { input = { }, output = { } }
for k,v in pairs(item.ingredients) do
  t.history.input[k] = Util.shallowCopy(v)
end
table.insert(item.history, t)

  Craft.craftRecipe(recipe, item.requested - item.crafted, context.storage, item)

for k,v in pairs(item.ingredients) do
  t.history.output[k] = Util.shallowCopy(v)
end

end

function craftTask:cycle()
  for _,key in pairs(Util.keys(context.craftingQueue)) do
    local item = context.craftingQueue[key]
    if item.requested - item.crafted > 0 then
      local recipe = Craft.findRecipe(key)
      if recipe then
        sync(turtle, function()
          self:craft(recipe, item)
        end)
        if item.callback and item.crafted >= item.requested then
          item.callback(item) -- invoke callback
        end
      elseif not context.controllerAdapter then
        item.status = '(no recipe)'
        item.statusCode = Craft.STATUS_ERROR
        item.crafted = 0
      end
    end
  end
end

Milo:registerTask(craftTask)