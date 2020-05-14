-- (Super)MultiFurnace Controller (did I mention, it's SUPER!?)
-- This app is designed to wrap up to 4 of kepler155c's furni.lua (multiFurni) arrays and divide up workload,
-- it functions as a straight drop-in for furni.lua and no other adjustments are required to make it work.
-- Additionally, you get the ability to target any one multiFurni array for smelting when creating the machine recipe in Milo
-- Further uses for this direct targeting can be limited-scope auto-smelting, using anywhere from 1/2 to 1/4 of your total
-- capacity to auto-smelt, leaving the rest of the cluster available for you when you want it, great for multi-user bases!

-- Plug this turtle into a modem on your Milo network, and another modem leading to 2-4 turtles running furni.lua (or even furniController.lua for chained setups)

-- Slots are as follows:
-- 1: Master Furnace Input
-- 2: Master Furnace Fuel Input
-- 3: Master Furnace Output
-- 4: Optional (Options: "fuel"/"input"/"output"/nil (Default: nil [ignore]))
-- 5-8: Furnace Inputs for 2 to 4 furni.lua arrays (slots mapped in order ascending, T1_Input=4, T2_Input=5, etc)
-- 9-12: Furnace Fuels for 2 to 4 furni.lua arrays
-- 13-16: Furnace Outputs for 2 to 4 furni.lua arrays

-- Only user option, slot 4, what to use it for?
local useSlot4=nil

-- Begin main program code
-- Find modem with -only- turtles attached (these should be our furni/furniController arrays)
local devModem=""
for nDev,modem in ipairs({peripheral.find("modem")}) do
  if #modem.getNamesRemote() > 1 then -- We're only looking for 2 or more devices on a network segment, ignore anything less
    nTurtles=0
    for nDev,dev in ipairs(modem.getNamesRemote()) do
      if modem.getTypeRemote(dev) == "turtle" then nTurtles=nTurtles+1 end
    end
    if nTurtles==#modem.getNamesRemote() then
      devModem=modem
      break
    end
  end
end
if devModem ~= "" then
  print("Found turtle-only modem, detected",#devModem.getNamesRemote(),"turtles",(#devModem.getNamesRemote() > 4 and "(Max 4 will be mapped)" or "(All will be mapped)"))
else
  print("Did not find a modem with only turtles connected. Please check your networking cables/modems and devices, then try again.")
  return -- We don't have a modem, halt
end
local devTurtles={}
for nDev,dev in ipairs(devModem.getNamesRemote()) do
  if #devTurtles >= 4 then break end
  devTurtles[#devTurtles+1]=peripheral.wrap(dev)
  print("Mapping",devTurtles[#devTurtles].getLabel(),"("..dev..")","as device",#devTurtles)
  devTurtles[#devTurtles].inputSlot=#devTurtles+4 -- Set the input for this device on second row
  devTurtles[#devTurtles].fuelSlot=#devTurtles+8 -- Set the fuel for this device on third row
  devTurtles[#devTurtles].outputSlot=#devTurtles+12 -- Set the output for this device on fourth row
  if devTurtles[#devTurtles].isOn() then
    print("Resynchronizing",devTurtles[#devTurtles].getLabel())
    devTurtles[#devTurtles].reboot()
  else
    print("Powering",devTurtles[#devTurtles].getLabel(),"on")
    devTurtles[#devTurtles].turnOn()
  end
end

local turtle.list = function () -- Supplement a local .list()-like function
  local tList={}
  for i=1,16 do
    local slotData=turtle.getItemDetail(i) -- DWGFJTLR
    if slotData ~= nil then
      slotData.maxStack=turtle.getItemCount(i) + turtle.getItemSpace(i)
      tList[i]=slotData
    end
  end
  return tList
end

function manageLocalResources()
  --print("Input found")
  local itemCount=turtle.getItemCount(1)/#devTurtles
  if itemCount < 1 then itemCount = 1 end -- Patch for single items fed into master slot
  if turtle.getItemCount(1) > 0 then -- Input
    for nDev,dev in ipairs(devTurtles) do
      local devList=dev.list()
      if turtle.select(1) and ((turtle.compareTo(dev.inputSlot) and turtle.getItemSpace(dev.inputSlot) > 0) or turtle.getItemCount(dev.inputSlot) == 0) then -- Move Input
        turtle.transferTo(dev.inputSlot,itemCount)
      end
      if useSlot4 == "input" and turtle.select(4) and ((turtle.compareTo(dev.inputSlot) and turtle.getItemSpace(dev.inputSlot) > 0) or turtle.getItemCount(dev.inputSlot) == 0) then -- Move Input
        turtle.transferTo(dev.inputSlot,itemCount)
      end --Slot 4 input
    end
  end
  if turtle.select(2) and turtle.getSelectedSlot() == 2 then -- Fuel
    for nDev,dev in ipairs(devTurtles) do
      local devList=dev.list()
      if turtle.compareTo(dev.fuelSlot) or turtle.getItemCount(dev.fuelSlot) == 0 then turtle.transferTo(dev.fuelSlot,64) end -- Move fuel into slot
    end
  end
  if useSlot4 == "fuel" and turtle.select(4) and turtle.getSelectedSlot() == 4 then -- Fuel
    for nDev,dev in ipairs(devTurtles) do
      local devList=dev.list()
      if turtle.compareTo(dev.fuelSlot) or turtle.getItemCount(dev.fuelSlot) == 0 then turtle.transferTo(dev.fuelSlot,64) end -- Move fuel into slot
    end
  end -- Slot 4 fuel

  for nDev,dev in ipairs(devTurtles) do
    local devList=dev.list()
    if turtle.getItemCount(3) == 0 and turtle.getItemCount(dev.outputSlot) > 0 then
        turtle.select(dev.outputSlot)
        turtle.transferTo(3,64)
    elseif turtle.getItemCount(dev.outputSlot) > 0 and turtle.select(3) and turtle.compareTo(dev.outputSlot) then -- Move output
      --turtle.setStatus("moving")
      turtle.select(dev.outputSlot)
      turtle.transferTo(3,64)
    end
    if useSlot4 == "output" then -- Slot 4 output
      if turtle.getItemCount(4) == 0 and turtle.getItemCount(dev.outputSlot) > 0 then
        turtle.select(dev.outputSlot)
        turtle.transferTo(4,64)
      elseif turtle.getItemCount(dev.outputSlot) > 0 and turtle.select(4) and turtle.compareTo(dev.outputSlot) then
        turtle.select(dev.outputSlot)
        turtle.transferTo(4,64)
      end
    end
  end
end

function manageRemoteResources()
  local localList=turtle.list()
  for nDev,dev in ipairs(devTurtles) do
    local devList=dev.list()
    --print(textutils.serialize(devList))
    if devList[2] == nil then
      if localList[dev.fuelSlot] ~= nil then
        turtle.setStatus("fueling")
        dev.pullItems(devModem.getNameLocal(),dev.fuelSlot,64,2)
      end
    else
      if localList[dev.fuelSlot] ~= nil and localList[dev.fuelSlot].name == devList[2].name then
        turtle.setStatus("fueling")
        dev.pullItems(devModem.getNameLocal(),dev.fuelSlot,64,2)
      end
    end
    if devList[1] == nil then
      if localList[dev.inputSlot] ~= nil then
        turtle.setStatus("pushing")
        dev.pullItems(devModem.getNameLocal(),dev.inputSlot,64,1)
      end
    else
      if localList[dev.inputSlot] ~= nil and localList[dev.inputSlot].name == devList[1].name then
        turtle.setStatus("pushing")
        dev.pullItems(devModem.getNameLocal(),dev.inputSlot,64,1)
      end
    end -- Move input
    if devList[3] ~= nil then
      if localList[dev.outputSlot] == nil then
        turtle.setStatus("pulling")
        dev.pushItems(devModem.getNameLocal(),3,64,dev.outputSlot)
      end
    else
      if localList[dev.outputSlot] ~= nil then
        if devList[3] ~= nil and localList[dev.outputSlot].name == devList[3].name then
          turtle.setStatus("pulling")
          dev.pushItems(devModem.getNameLocal(),3,64,dev.outputSlot)
        end
      end
    end
  end
end

local lastList={}
while true do -- Main Loop
  local turtleList=turtle.list()
  if turtleList[1]~=nil or turtleList[13]~=nil or turtleList[14]~=nil or turtleList[15]~=nil or turtleList[16]~=nil or ((useSlot4=="input" or useSlot4=="fuel") and turtleList[4]~=nil) then
    manageLocalResources()
  end
  manageRemoteResources()
  turtle.setStatus("sleeping")
  os.sleep(1)
end
