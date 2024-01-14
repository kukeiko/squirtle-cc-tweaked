local Utils = require "utils"
local Inventory = require "inventory.inventory"
local Elemental = require "squirtle.elemental"
local Basic = require "squirtle.basic"

local bucket = "minecraft:bucket"
local fuelItems = {["minecraft:lava_bucket"] = 1000, ["minecraft:coal"] = 80, ["minecraft:charcoal"] = 80, ["minecraft:coal_block"] = 800}

---@return integer
local function getTransferRate()
    return 16
end

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

    local items = Inventory.getStacks(inventory)

    if items[1] == nil then
        Inventory.move(inventory, slot, 1, quantity)
        local success, message = Elemental.suck(inventory, quantity)
        Inventory.move(inventory, 1, slot)

        return success, message
    end

    local firstEmptySlot = Utils.firstEmptySlot(items, Inventory.getSize(inventory))

    if not firstEmptySlot and Basic.isFull() then
        error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", inventory))
    elseif firstEmptySlot then
        Inventory.move(inventory, 1, firstEmptySlot)
        Inventory.move(inventory, slot, 1, quantity)
        local success, message = Elemental.suck(inventory, quantity)
        Inventory.move(inventory, 1, slot)

        return success, message
    else
        local initialSlot = Elemental.getSelectedSlot()
        Basic.selectFirstEmpty()
        Elemental.suck(inventory)
        Inventory.move(inventory, slot, 1)
        Elemental.drop(inventory)
        local success, message = Elemental.suck(inventory, quantity)
        Elemental.select(initialSlot)

        return success, message
    end
end

-- [todo] keepStock is not used yet anywhere; but i want to keep it because it should (imo)
-- be used @ lumberjack to push birch-saplings, but make sure to always keep at least 32.
-- [todo] also, I did not yet think about how keepStock (if provided) influences pullInput()
-- in regards to the calculation of transferrable input
---@param from Inventory|string
---@param to InputOutputInventory|string
---@param keepStock? table<string, integer>
---@return boolean, table<string, integer>? transferred
function Advanced.pushOutput(from, to, keepStock)
    keepStock = keepStock or {}

    if type(from) == "string" then
        from = Inventory.create(from)
    end

    if type(to) == "string" then
        to = Inventory.createInputOutput_old(to)
    end

    ---@type table<string, integer>
    local transferrable = {}

    for item, toStock in pairs(to.output.stock) do
        local fromStock = from.stock[item]

        if toStock.count < toStock.maxCount and fromStock and fromStock.count - (keepStock[item] or 0) > 0 then
            transferrable[item] = math.min(toStock.maxCount - toStock.count, fromStock.count - (keepStock[item] or 0))
        end
    end

    local transferred = Inventory.transferItems(from, to.output, transferrable, getTransferRate())
    local transferredAll = true

    for item, itemTransferred in pairs(transferred) do
        if itemTransferred < transferrable[item] then
            transferredAll = false
        end
    end

    if Utils.count(transferred) == 0 then
        return transferredAll, nil
    end

    return transferredAll, transferred
end

-- in regards to the calculation of transferrable input
---@param from Inventory|string
---@param to InputOutputInventory|string
---@return boolean, table<string, integer>? transferred
function Advanced.dumpOutput(from, to)
    if type(from) == "string" then
        from = Inventory.create(from)
    end

    if type(to) == "string" then
        -- [todo] only supports I/O chests currently
        to = Inventory.createInputOutput_old(to)
    end

    ---@type table<string, integer>
    local transferrable = {}

    for item, stock in pairs(from.stock) do
        transferrable[item] = stock.count
    end

    local transferred = Inventory.transferItems(from, to.output, transferrable, getTransferRate(), true)
    local transferredAll = true

    for item, itemTransferred in pairs(transferred) do
        if itemTransferred < transferrable[item] then
            transferredAll = false
        end
    end

    if Utils.count(transferred) == 0 then
        return transferredAll, nil
    end

    return transferredAll, transferred
end

---@param from InputOutputInventory|string
---@param to Inventory|string
---@param transferredOutput? table<string, integer>
---@return boolean, table<string, integer>? transferred
function Advanced.pullInput(from, to, transferredOutput)
    if type(from) == "string" then
        from = Inventory.createInputOutput_old(from)
    end

    if type(to) == "string" then
        to = Inventory.create(to)
    end

    transferredOutput = transferredOutput or {}
    ---@type table<string, integer>
    local transferrable = {}

    for item, stock in pairs(from.input.stock) do
        local transfer = stock.maxCount

        if from.output.stock[item] then
            transfer = transfer + from.output.stock[item].maxCount
        end

        transfer = transfer - (transferredOutput[item] or 0)

        local toStock = to.stock[item]

        if toStock then
            transfer = transfer - toStock.count
        end

        transferrable[item] = math.min(stock.count, transfer)
    end

    local transferred = Inventory.transferItems(from.input, to, transferrable, getTransferRate(), true)
    local transferredAll = true

    for item, itemTransferred in pairs(transferred) do
        if itemTransferred < transferrable[item] then
            transferredAll = false
        end
    end

    if Utils.count(transferred) == 0 then
        return transferredAll, nil
    end

    return transferredAll, transferred
end

return Advanced
