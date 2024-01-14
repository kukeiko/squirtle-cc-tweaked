local EventLoop = require "event-loop"
local Inventory = require "inventory.inventory"

---@param collection InventoryCollection
---@param timeout integer
return function(collection, timeout)
    while true do
        parallel.waitForAny(function()
            os.sleep(timeout)
        end, function()
            while true do
                local _, key = EventLoop.pull("key")
                if key == keys.space or key == keys.enter then
                    break
                end
            end
        end)

        print("[refresh] storages")
        local storages = collection:getInventories("storage")

        for _, storage in pairs(storages) do
            local refreshed = Inventory.readInputOutput(storage.name)

            if refreshed and refreshed.type ~= "storage" then
                print("[refresh] type changed")
                os.queueEvent("peripheral_detach", storage.name)
                os.queueEvent("peripheral", storage.name)
            elseif refreshed then
                collection:remove(refreshed.name)
                collection:add(refreshed)
            end
        end
    end
end
