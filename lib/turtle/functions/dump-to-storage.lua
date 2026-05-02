local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local ItemStock = require "lib.inventory.item-stock"

---@param TurtleApi TurtleApi
---@param keepStock ItemStock
---@return boolean
local function moveOpenToIoSlots(TurtleApi, keepStock)
    local movableStock = ItemStock.subtract(TurtleApi.getStock(false, true), keepStock)

    if Utils.isEmpty(movableStock) then
        return false
    end

    -- [todo] ❌ once this works, I really should make use of InventoryApi functions
    local nonIoSlots = TurtleApi.getNonIoSlots()

    for _, ioSlot in ipairs(TurtleApi.getIoSlots()) do
        local ioStack = TurtleApi.getStack(ioSlot)

        if ioStack and TurtleApi.getItemSpace(ioSlot) > 0 then
            local openQuantity = movableStock[ioStack.name]

            if openQuantity and openQuantity > 0 then
                local fromSlot = TurtleApi.find(ioStack.name, nil, nonIoSlots)

                if fromSlot then
                    TurtleApi.select(fromSlot)
                    local _, transferred = TurtleApi.transferTo(ioSlot, math.min(openQuantity, 64))
                    movableStock[ioStack.name] = movableStock[ioStack.name] - transferred
                end
            end
        elseif not ioStack then
            for _, fromSlot in ipairs(nonIoSlots) do
                local stack = TurtleApi.getStack(fromSlot)

                if stack and movableStock[stack.name] then
                    local openQuantity = movableStock[stack.name]
                    TurtleApi.select(fromSlot)
                    local _, transferred = TurtleApi.transferTo(ioSlot, math.min(openQuantity, 64))
                    movableStock[stack.name] = movableStock[stack.name] - transferred
                end
            end
        end
    end

    return true
end

---@param TurtleApi TurtleApi
---@param items ItemStock
return function(TurtleApi, items)
    local ioSlots = TurtleApi.getIoSlots()
    local keepStock = ItemStock.subtract(TurtleApi.getStock(true), items)

    local function getOpen()
        return ItemStock.subtract(TurtleApi.getStock(true), keepStock)
    end

    -- [todo] ❌ missing logic to move items that are not to be dumped out of the io slots
    TurtleApi.connectToStorage(function(inventory, storage)
        local storages = storage.getByType("storage")

        EventLoop.waitForAny(function()
            while true do
                -- [todo] ❌ i think this can crash the turtle because of simultaneous access to shulkers
                local open = getOpen()
                -- [todo] ❌ hack: should be up to storage to define toSequential or not, for now it is here to support autoStorage
                storage.transfer({inventory}, storages, open, {toSequential = true})
                os.sleep(1)
            end
        end, function()
            while true do
                local open = getOpen()

                if Utils.isEmpty(open) then
                    break
                end

                while moveOpenToIoSlots(TurtleApi, keepStock) do
                    os.sleep(1)
                end

                local i = 0

                for item, _ in pairs(open) do
                    while i < #ioSlots do
                        if TurtleApi.loadFromShulker(item, true) then
                            i = i + 1
                        else
                            break
                        end
                    end
                end

                os.sleep(1)
            end
        end)
    end)

    TurtleApi.digShulkers()
    TurtleApi.condense()
end
