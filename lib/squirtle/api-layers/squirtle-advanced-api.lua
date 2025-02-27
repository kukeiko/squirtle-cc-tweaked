local Utils = require "lib.tools.utils"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local Inventory = require "lib.apis.inventory-api"
local SquirtleElementalApi = require "lib.squirtle.api-layers.squirtle-elemental-api"
local SquirtleBasicApi = require "lib.squirtle.api-layers.squirtle-basic-api"

local bucket = "minecraft:bucket"
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

---@class SquirtleAdvancedApi : SquirtleBasicApi
local SquirtleAdvancedApi = {}
setmetatable(SquirtleAdvancedApi, {__index = SquirtleBasicApi})

---@param stacks ItemStack[]
---@param fuel number
---@param allowLava? boolean
---@return ItemStack[] fuelStacks, number openFuel
local function pickFuelStacks(stacks, fuel, allowLava)
    local pickedStacks = {}
    local openFuel = fuel

    for slot, stack in pairs(stacks) do
        if fuelItems[stack.name] and (allowLava or stack.name ~= "minecraft:lava_bucket") then
            local itemRefuelAmount = fuelItems[stack.name]
            local numItems = math.ceil(openFuel / itemRefuelAmount)
            stack = Utils.clone(stack)
            stack.count = numItems
            pickedStacks[slot] = stack
            openFuel = openFuel - (numItems * itemRefuelAmount)

            if openFuel <= 0 then
                break
            end
        end
    end

    return pickedStacks, math.max(openFuel, 0)
end

---@param fuel? integer
---@param allowLava? boolean
local function refuelFromBackpack(fuel, allowLava)
    fuel = fuel or SquirtleBasicApi.missingFuel()
    local fuelStacks = pickFuelStacks(SquirtleBasicApi.getStacks(), fuel, allowLava)
    local emptyBucketSlot = SquirtleBasicApi.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        SquirtleBasicApi.select(slot)
        SquirtleBasicApi.refuel(stack.count)

        local remaining = SquirtleBasicApi.getStack(slot)

        if remaining and remaining.name == bucket then
            if not emptyBucketSlot or not SquirtleBasicApi.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or SquirtleBasicApi.missingFuel()
    local _, y = term.getCursorPos()

    while not SquirtleBasicApi.hasFuel(fuel) do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - SquirtleBasicApi.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function SquirtleAdvancedApi.refuelTo(fuel)
    if SquirtleBasicApi.hasFuel(fuel) then
        return true
    elseif fuel > SquirtleBasicApi.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - SquirtleBasicApi.getFuelLimit()))
    end

    refuelFromBackpack(fuel)

    if not SquirtleBasicApi.hasFuel(fuel) then
        refuelWithHelpFromPlayer(fuel)
    end
end

---@param inventory string
---@param slot integer
---@param quantity? integer
---@return boolean, string?
function SquirtleAdvancedApi.suckSlot(inventory, slot, quantity)
    if slot == 1 then
        return SquirtleElementalApi.suck(inventory, quantity)
    end

    local items = InventoryPeripheral.getStacks(inventory)

    if items[1] == nil then
        InventoryPeripheral.move(inventory, slot, 1, quantity)
        local success, message = SquirtleElementalApi.suck(inventory, quantity)
        InventoryPeripheral.move(inventory, 1, slot)

        return success, message
    end

    local firstEmptySlot = Utils.firstEmptySlot(items, InventoryPeripheral.getSize(inventory))

    if not firstEmptySlot and SquirtleBasicApi.isFull() then
        error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", inventory))
    elseif firstEmptySlot then
        InventoryPeripheral.move(inventory, 1, firstEmptySlot)
        InventoryPeripheral.move(inventory, slot, 1, quantity)
        local success, message = SquirtleElementalApi.suck(inventory, quantity)
        InventoryPeripheral.move(inventory, 1, slot)

        return success, message
    else
        local initialSlot = SquirtleElementalApi.getSelectedSlot()
        SquirtleBasicApi.selectFirstEmpty()
        SquirtleElementalApi.suck(inventory)
        InventoryPeripheral.move(inventory, slot, 1)
        SquirtleElementalApi.drop(inventory)
        local success, message = SquirtleElementalApi.suck(inventory, quantity)
        SquirtleElementalApi.select(initialSlot)

        return success, message
    end
end

---@param from string
---@param to string
---@return ItemStock transferredTotal, ItemStock open
function SquirtleAdvancedApi.pushOutput(from, to)
    return Inventory.transfer({from}, "buffer", {to}, "output")
end

---@param from string
---@param to string
function SquirtleAdvancedApi.pushAllOutput(from, to)
    local _, open = SquirtleAdvancedApi.pushOutput(from, to)

    if Utils.count(open) > 0 then
        print("output full, waiting...")
    end

    while Utils.count(open) > 0 do
        os.sleep(7)
        _, open = SquirtleAdvancedApi.pushOutput(from, to)
    end
end

---@param from string
---@param to string
---@param transferredOutput? ItemStock
---@return ItemStock transferredTotal, ItemStock open
function SquirtleAdvancedApi.pullInput(from, to, transferredOutput)
    local fromMaxInputStock = Inventory.getMaxStock({from}, "input")
    local fromMaxOutputStock = Inventory.getMaxStock({from}, "output")
    local toStock = Inventory.getStock({to}, "buffer")
    transferredOutput = transferredOutput or {}

    ---@type ItemStock
    local items = {}

    -- in case the chest we're pulling from has the same item in input as it does in output,
    -- we need to make sure to not pull more input than is allowed by checking what parts of
    -- the "to" chest are output stock.
    for item, maxInputStock in pairs(fromMaxInputStock) do
        local inputInToStock = toStock[item] or 0

        if fromMaxOutputStock[item] and toStock[item] then
            inputInToStock = (toStock[item] + (transferredOutput[item] or 0)) - fromMaxOutputStock[item]
        end

        items[item] = math.min(maxInputStock - inputInToStock, Inventory.getItemCount({from}, item, "input"))
    end

    return Inventory.transfer({from}, "input", {to}, "buffer", items)
end

return SquirtleAdvancedApi
