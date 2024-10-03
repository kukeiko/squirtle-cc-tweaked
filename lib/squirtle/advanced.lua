local Utils = require "lib.utils"
local InventoryPeripheral = require "lib.inventory.inventory-peripheral"
local Inventory = require "lib.inventory"
local Elemental = require "lib.squirtle.elemental"
local Basic = require "lib.squirtle.basic"

local bucket = "minecraft:bucket"
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

---@class Advanced : Basic
local Advanced = {}
setmetatable(Advanced, {__index = Basic})

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
    fuel = fuel or Basic.missingFuel()
    local fuelStacks = pickFuelStacks(Basic.getStacks(), fuel, allowLava)
    local emptyBucketSlot = Basic.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        Basic.select(slot)
        Basic.refuel(stack.count)

        local remaining = Basic.getStack(slot)

        if remaining and remaining.name == bucket then
            if not emptyBucketSlot or not Basic.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or Basic.missingFuel()
    local _, y = term.getCursorPos()

    while not Basic.hasFuel(fuel) do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - Basic.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function Advanced.refuelTo(fuel)
    if Basic.hasFuel(fuel) then
        return true
    elseif fuel > Basic.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - Basic.getFuelLimit()))
    end

    refuelFromBackpack(fuel)

    if not Basic.hasFuel(fuel) then
        refuelWithHelpFromPlayer(fuel)
    end
end

---@param inventory string
---@param slot integer
---@param quantity? integer
---@return boolean, string?
function Advanced.suckSlot(inventory, slot, quantity)
    if slot == 1 then
        return Elemental.suck(inventory, quantity)
    end

    local items = InventoryPeripheral.getStacks(inventory)

    if items[1] == nil then
        InventoryPeripheral.move(inventory, slot, 1, quantity)
        local success, message = Elemental.suck(inventory, quantity)
        InventoryPeripheral.move(inventory, 1, slot)

        return success, message
    end

    local firstEmptySlot = Utils.firstEmptySlot(items, InventoryPeripheral.getSize(inventory))

    if not firstEmptySlot and Basic.isFull() then
        error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", inventory))
    elseif firstEmptySlot then
        InventoryPeripheral.move(inventory, 1, firstEmptySlot)
        InventoryPeripheral.move(inventory, slot, 1, quantity)
        local success, message = Elemental.suck(inventory, quantity)
        InventoryPeripheral.move(inventory, 1, slot)

        return success, message
    else
        local initialSlot = Elemental.getSelectedSlot()
        Basic.selectFirstEmpty()
        Elemental.suck(inventory)
        InventoryPeripheral.move(inventory, slot, 1)
        Elemental.drop(inventory)
        local success, message = Elemental.suck(inventory, quantity)
        Elemental.select(initialSlot)

        return success, message
    end
end

---@param from string
---@param to string
---@return ItemStock transferredTotal, ItemStock open
function Advanced.pushOutput(from, to)
    return Inventory.transferFromTag(from, to, "output", "output")
end

---@param from string
---@param to string
function Advanced.pushAllOutput(from, to)
    local _, open = Advanced.pushOutput(from, to)

    if Utils.count(open) > 0 then
        print("output full, waiting...")
    end

    while Utils.count(open) > 0 do
        os.sleep(7)
        _, open = Advanced.pushOutput(from, to)
    end
end

---@param from string
---@param to string
---@param transferredOutput? ItemStock
---@return ItemStock transferredTotal, ItemStock open
function Advanced.pullInput(from, to, transferredOutput)
    local fromMaxInputStock = Inventory.getMaxStockByTag(from, "input")
    local fromMaxOutputStock = Inventory.getMaxStockByTag(from, "output")
    local toStock = Inventory.getInventoryStockByTag(to, "input")
    transferredOutput = transferredOutput or {}

    ---@type ItemStock
    local total = {}

    -- in case the chest we're pulling from has the same item in input as it does in output,
    -- we need to make sure to not pull more input than is allowed by checking what parts of
    -- the "to" chest are output stock.
    for item, maxInputStock in pairs(fromMaxInputStock) do
        local inputInToStock = toStock[item] or 0

        if fromMaxOutputStock[item] and toStock[item] then
            inputInToStock = (toStock[item] + (transferredOutput[item] or 0)) - fromMaxOutputStock[item]
        end

        total[item] = math.min(maxInputStock - inputInToStock, Inventory.getItemStockByTag(from, "input", item))
    end

    return Inventory.transferFromTag(from, to, "input", "input", total)
end

return Advanced
