local EventLoop = require "event-loop"
local transferStock = require "io-network.transfer-stock"
local Inventory = require "inventory.inventory"

---@param name string
local function waitUntilDetached(name)
    while true do
        local _, detachedName = EventLoop.pull("peripheral_detach")

        if detachedName == name then
            break
        end
    end
end

---@param collection InventoryCollection
---@param inventory InputOutputInventory
---@param timeout integer
return function(collection, inventory, timeout)
    parallel.waitForAny(function()
        pcall(function()
            while true do
                local refreshed = Inventory.read(inventory.name)

                if not refreshed or refreshed.type ~= inventory.type then
                    print("[debug] type changed")
                    EventLoop.queue("peripheral_detach", inventory.name)
                    EventLoop.queue("peripheral", inventory.name)
                else
                    collection:remove(refreshed.name)
                    collection:add(refreshed)
                    inventory = refreshed
                    local outputStock = inventory.output.stock
                    local inputInventories = collection:getInventories("storage", "io")
                    transferStock(outputStock, {inventory}, inputInventories, collection)
                    os.sleep(timeout)
                end
            end
        end)
    end, function()
        waitUntilDetached(inventory.name)
    end)
end
