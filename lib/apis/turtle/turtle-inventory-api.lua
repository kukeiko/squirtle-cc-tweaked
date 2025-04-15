local Utils = require "lib.tools.utils"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"
local InventoryApi = require "lib.apis.inventory.inventory-api"
local getNative = require "lib.apis.turtle.functions.get-native"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local TurtleSharedApi = require "lib.apis.turtle.turtle-shared-api"

-- [todo] already copied methods from: Elemental, Basic
---@class TurtleInventoryApi
local TurtleInventoryApi = {}

---@return integer
function TurtleInventoryApi.size()
    return 16
end

---@param slot? integer
---@return integer
function TurtleInventoryApi.getItemCount(slot)
    return turtle.getItemCount(slot)
end

---@param slot? integer
---@return integer
function TurtleInventoryApi.getItemSpace(slot)
    return turtle.getItemSpace(slot)
end

---@param slot integer
---@return boolean
function TurtleInventoryApi.select(slot)
    if TurtleStateApi.isSimulating() then
        return true
    end

    return turtle.select(slot)
end

---@return integer
function TurtleInventoryApi.getSelectedSlot()
    return turtle.getSelectedSlot()
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function TurtleInventoryApi.getStack(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end

---@param slot integer
---@param quantity? integer
---@return boolean
function TurtleInventoryApi.transferTo(slot, quantity)
    return turtle.transferTo(slot, quantity)
end

---@param slot integer
---@return boolean
function TurtleInventoryApi.selectIfNotEmpty(slot)
    if TurtleInventoryApi.getItemCount(slot) > 0 then
        return TurtleInventoryApi.select(slot)
    else
        return false
    end
end

---@param startAt? number
---@return integer
function TurtleInventoryApi.selectEmpty(startAt)
    startAt = startAt or turtle.getSelectedSlot()

    for i = 0, TurtleInventoryApi.size() - 1 do
        local slot = startAt + i

        if slot > TurtleInventoryApi.size() then
            slot = slot - TurtleInventoryApi.size()
        end

        if TurtleInventoryApi.getItemCount(slot) == 0 then
            TurtleInventoryApi.select(slot)

            return slot
        end
    end

    error("no empty slot available")
end

---@return integer
function TurtleInventoryApi.selectFirstEmpty()
    return TurtleInventoryApi.selectEmpty(1)
end

---@param startAt? number
function TurtleInventoryApi.firstEmptySlot(startAt)
    -- [todo] this startAt logic works a bit differently to "Backpack.selectEmpty()" as it does not wrap around
    startAt = startAt or 1

    for slot = startAt, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return integer
function TurtleInventoryApi.numEmptySlots()
    local numEmpty = 0

    for slot = 1, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function TurtleInventoryApi.isFull()
    for slot = 1, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

---@return boolean
function TurtleInventoryApi.isEmpty()
    for slot = 1, TurtleInventoryApi.size() do
        if TurtleInventoryApi.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

---@return ItemStack[]
function TurtleInventoryApi.getStacks()
    local stacks = {}

    for slot = 1, TurtleInventoryApi.size() do
        local item = TurtleInventoryApi.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@param predicate string|function<boolean, ItemStack>
---@return integer
function TurtleInventoryApi.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(TurtleInventoryApi.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@return table<string, integer>
function TurtleInventoryApi.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(TurtleInventoryApi.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param name string
---@param exact? boolean
---@param startAtSlot? integer
---@return integer?
function TurtleInventoryApi.find(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, TurtleInventoryApi.size() do
        local item = TurtleInventoryApi.getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and not exact and string.find(item.name, name) then
            return slot
        end
    end
end

---@param item string
---@param minCount? integer
---@return boolean
function TurtleInventoryApi.has(item, minCount)
    if type(minCount) == "number" then
        return TurtleInventoryApi.getItemStock(item) >= minCount
    else
        for slot = 1, TurtleInventoryApi.size() do
            local stack = TurtleInventoryApi.getStack(slot)

            if stack and stack.name == item then
                return true
            end
        end

        return false
    end
end

---Condenses the inventory by stacking matching items.
function TurtleInventoryApi.condense()
    if TurtleStateApi.isSimulating() then
        return nil
    end

    for slot = TurtleInventoryApi.size(), 1, -1 do
        local item = TurtleInventoryApi.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = TurtleInventoryApi.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    TurtleInventoryApi.select(slot)
                    TurtleInventoryApi.transferTo(targetSlot)

                    if TurtleInventoryApi.getItemCount(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    TurtleInventoryApi.select(slot)
                    TurtleInventoryApi.transferTo(targetSlot)
                    break
                end
            end
        end
    end
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function TurtleInventoryApi.drop(direction, count)
    if TurtleStateApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    return getNative("drop", direction)(count)
end

---@param side string
---@return boolean success if everything could be dumped
function TurtleInventoryApi.dump(side)
    local items = TurtleInventoryApi.getStacks()

    for slot in pairs(items) do
        TurtleInventoryApi.select(slot)
        TurtleInventoryApi.drop(side)
    end

    return TurtleInventoryApi.isEmpty()
end

---@param direction? string
---@param count? integer
---@return boolean, string?
function TurtleInventoryApi.suck(direction, count)
    if TurtleStateApi.isSimulating() then
        return true
    end

    direction = direction or "forward"
    return getNative("suck", direction)(count)
end

---@param direction? string
function TurtleInventoryApi.suckAll(direction)
    while TurtleInventoryApi.suck(direction) do
    end
end

---@param inventory string
---@param slot integer
---@param quantity? integer
---@return boolean, string?
function TurtleInventoryApi.suckSlot(inventory, slot, quantity)
    local stacks = InventoryPeripheral.getStacks(inventory)
    local stack = stacks[slot]

    if not stack then
        return false
    end

    quantity = math.min(quantity or stack.count, stack.count)

    if InventoryPeripheral.getFirstOccupiedSlot(inventory) == slot then
        return TurtleInventoryApi.suck(inventory, quantity)
    end

    if stacks[1] == nil then
        InventoryPeripheral.move(inventory, slot, 1)
        os.sleep(.25) -- [todo] move to suck()
        return TurtleInventoryApi.suck(inventory, quantity)
    end

    local firstEmptySlot = Utils.firstEmptySlot(stacks, InventoryPeripheral.getSize(inventory))

    if firstEmptySlot then
        InventoryPeripheral.move(inventory, 1, firstEmptySlot)
        InventoryPeripheral.move(inventory, slot, 1)
        os.sleep(.25) -- [todo] move to suck()
        return TurtleInventoryApi.suck(inventory, quantity)
    elseif TurtleInventoryApi.isFull() then
        error(string.format("inventory %s is full. i'm also full, so no temporary unloading possible.", inventory))
    else
        local initialSlot = TurtleInventoryApi.getSelectedSlot()
        TurtleInventoryApi.selectFirstEmpty()
        TurtleInventoryApi.suck(inventory)
        InventoryPeripheral.move(inventory, slot, 1)
        TurtleInventoryApi.drop(inventory)
        os.sleep(.25) -- [todo] move to suck()
        TurtleInventoryApi.select(initialSlot)

        return TurtleInventoryApi.suck(inventory, quantity)
    end
end

---@param inventory string
---@param item string
---@param quantity integer
---@return boolean success
function TurtleInventoryApi.suckItem(inventory, item, quantity)
    local open = quantity

    while open > 0 do
        -- we want to get refreshed stacks every iteration as suckSlot() manipulates the inventory state
        local stacks = InventoryPeripheral.getStacks(inventory)
        local found = false

        for slot, stack in pairs(stacks) do
            if stack.name == item then
                if not TurtleInventoryApi.suckSlot(inventory, slot, math.min(open, stack.count)) then
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
function TurtleInventoryApi.pushOutput(from, to, keep)
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
function TurtleInventoryApi.pushAllOutput(from, to)
    local logged = false

    while not TurtleInventoryApi.pushOutput(from, to) do
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
function TurtleInventoryApi.pullInput(from, to, transferredOutput, max)
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

---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(alsoIgnoreSlot)
    for slot = 1, 16 do
        if alsoIgnoreSlot ~= slot then
            local item = TurtleInventoryApi.getStack(slot)

            if item and item.name ~= "minecraft:shulker_box" then
                return slot
            end
        end
    end
end

---@param shulker integer
---@param item string
---@return boolean
local function loadFromShulker(shulker, item)
    TurtleInventoryApi.select(shulker)
    local placedSide = TurtleSharedApi.placeShulker()

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = InventoryPeripheral.getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            TurtleInventoryApi.suckSlot(placedSide, stackSlot)
            local emptySlot = TurtleInventoryApi.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                TurtleInventoryApi.select(slotToPutIntoShulker)
                TurtleInventoryApi.drop(placedSide)
                TurtleInventoryApi.select(shulker)
            end

            TurtleSharedApi.digShulker(placedSide)

            return true
        end
    end

    TurtleSharedApi.digShulker(placedSide)

    return false
end

---@param name string
---@return false|integer
function TurtleInventoryApi.selectItem(name)
    if TurtleStateApi.isSimulating() then
        return false
    end

    local slot = TurtleInventoryApi.find(name, true)

    if not slot then
        local nextShulkerSlot = 1

        while true do
            local shulker = TurtleInventoryApi.find("minecraft:shulker_box", true, nextShulkerSlot)

            if not shulker then
                break
            end

            if loadFromShulker(shulker, name) then
                -- [note] we can return "shulker" here because the item loaded from the shulker box ends
                -- up in the slot the shulker originally was
                return shulker
            end

            nextShulkerSlot = nextShulkerSlot + 1
        end

        return false
    end

    TurtleInventoryApi.select(slot)

    return slot
end

---@param direction string
---@return boolean unloadedAll
local function loadIntoShulker(direction)
    local unloadedAll = true

    for slot = 1, TurtleInventoryApi.size() do
        local stack = TurtleInventoryApi.getStack(slot)

        if stack and not stack.name == "minecraft:shulker_box" and not stack.name == "computercraft:disk_drive" then
            TurtleInventoryApi.select(slot)

            if not TurtleInventoryApi.drop(direction) then
                unloadedAll = false
            end
        end
    end

    return unloadedAll
end

---@return boolean unloadedAll
function TurtleInventoryApi.tryLoadShulkers()
    ---@type string?
    local placedSide = nil

    for slot = 1, TurtleInventoryApi.size() do
        local stack = TurtleInventoryApi.getStack(slot)

        if stack and stack.name == "minecraft:shulker_box" then
            TurtleInventoryApi.select(slot)
            placedSide = TurtleSharedApi.placeShulker()
            local unloadedAll = loadIntoShulker(placedSide)
            TurtleInventoryApi.select(slot)
            TurtleSharedApi.digShulker(placedSide)

            if unloadedAll then
                return true
            end
        end
    end

    return false
end

return TurtleInventoryApi
