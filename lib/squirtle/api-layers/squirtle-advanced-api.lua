local Utils = require "lib.tools.utils"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local InventoryApi = require "lib.apis.inventory.inventory-api"
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
    local stacks = InventoryPeripheral.getStacks(inventory)
    local stack = stacks[slot]

    if not stack then
        return false
    end

    quantity = math.min(quantity or stack.count, stack.count)

    if InventoryPeripheral.getFirstOccupiedSlot(inventory) == slot then
        return SquirtleElementalApi.suck(inventory, quantity)
    end

    if stacks[1] == nil then
        InventoryPeripheral.move(inventory, slot, 1)
        os.sleep(.25) -- [todo] move to suck()
        return SquirtleElementalApi.suck(inventory, quantity)
    end

    local firstEmptySlot = Utils.firstEmptySlot(stacks, InventoryPeripheral.getSize(inventory))

    if firstEmptySlot then
        InventoryPeripheral.move(inventory, 1, firstEmptySlot)
        InventoryPeripheral.move(inventory, slot, 1)
        os.sleep(.25) -- [todo] move to suck()
        return SquirtleElementalApi.suck(inventory, quantity)
    elseif SquirtleBasicApi.isFull() then
        error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", inventory))
    else
        local initialSlot = SquirtleElementalApi.getSelectedSlot()
        SquirtleBasicApi.selectFirstEmpty()
        SquirtleElementalApi.suck(inventory)
        InventoryPeripheral.move(inventory, slot, 1)
        SquirtleElementalApi.drop(inventory)
        os.sleep(.25) -- [todo] move to suck()
        SquirtleElementalApi.select(initialSlot)

        return SquirtleElementalApi.suck(inventory, quantity)
    end
end

---@param inventory string
---@param item string
---@param quantity integer
---@return boolean success
function SquirtleAdvancedApi.suckItem(inventory, item, quantity)
    local open = quantity

    while open > 0 do
        -- we want to get refreshed stacks every iteration as suckSlot() manipulates the inventory state
        local stacks = InventoryPeripheral.getStacks(inventory)
        local found = false

        for slot, stack in pairs(stacks) do
            if stack.name == item then
                if not SquirtleAdvancedApi.suckSlot(inventory, slot, math.min(open, stack.count)) then
                    return false
                end

                found = true
                open = open - stack.count

                if open <= 0 then
                    break
                end
            end
        end

        if not found then
            return false
        end
    end

    return true
end

---@param from string
---@param to string
---@param keep? ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function SquirtleAdvancedApi.pushOutput(from, to, keep)
    keep = keep or {}
    local bufferStock = InventoryApi.getStock({from}, "buffer")
    local outputStock = InventoryApi.getStock({to}, "output")
    ---@type ItemStock
    local stock = {}

    for item in pairs(outputStock) do
        if bufferStock[item] then
            stock[item] = math.max(0, bufferStock[item] - (keep[item] or 0))
        end
    end

    return InventoryApi.transfer({from}, {to}, stock, {fromTag = "buffer"})
end

---@param from string
---@param to string
function SquirtleAdvancedApi.pushAllOutput(from, to)
    local logged = false

    while not SquirtleAdvancedApi.pushOutput(from, to) do
        if not logged then
            print("[busy] output full, waiting...")
            logged = true
        end

        os.sleep(7)
    end
end

---@param from string
---@param to string
---@param transferredOutput? ItemStock
---@param max? ItemStock
---@return boolean success, ItemStock transferred, ItemStock open
function SquirtleAdvancedApi.pullInput(from, to, transferredOutput, max)
    local fromMaxInputStock = InventoryApi.getMaxStock({from}, "input")
    local fromMaxOutputStock = InventoryApi.getMaxStock({from}, "output")
    local toStock = InventoryApi.getStock({to}, "buffer")
    transferredOutput = transferredOutput or {}
    max = max or {}

    ---@type ItemStock
    local items = {}

    for item, maxInputStock in pairs(fromMaxInputStock) do
        if max[item] then
            maxInputStock = math.min(maxInputStock, max[item])
        end

        local inputInToStock = toStock[item] or 0

        if fromMaxOutputStock[item] and toStock[item] then
            -- in case the chest we're pulling from has the same item in input as it does in output,
            -- we need to make sure to not pull more input than is allowed by checking what parts of
            -- the "to" chest are output stock.
            inputInToStock = (inputInToStock + (transferredOutput[item] or 0)) - fromMaxOutputStock[item]
        end

        items[item] = math.min(maxInputStock - inputInToStock, InventoryApi.getItemCount({from}, item, "input"))
    end

    return InventoryApi.transfer({from}, {to}, items, {fromTag = "input", toTag = "buffer"})
end

return SquirtleAdvancedApi
