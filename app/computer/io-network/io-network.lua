package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local concatTables = require "utils.concat-tables"
local findPeripheralSide = require "world.peripheral.find-side"
local findInventories = require "io-network.find-inventories"
local readInventories = require "io-network.read-inventories"
local groupInventoriesByType = require "io-network.group-inventories-by-type"
local spreadOutputOfInventory = require "io-network.spread-output-of-inventory"
local printFoundInventories = require "io-network.print-found-inventories"
local waitTimeoutOrUntilKeyEvent = require "io-network.wait-timeout-or-until-key-event"

---@class NetworkedInventory : InputOutputInventory
---@field type "storage" | "io" | "drain" | "furnace" | "silo"
---@field name string

---@class NetworkedInventoriesByType
---@field storage NetworkedInventory[]
---@field io NetworkedInventory[]
---@field drain NetworkedInventory[]
---@field furnace NetworkedInventory[]
---@field silo NetworkedInventory[]

---@class FoundInventory
---@field name string
---@field type string

-- [todo] we should not only spread an item (e.g. charcoal) evenly amongst inputs,
-- but also evenly from outputs, so that e.g. the 4 lumberjack farms all start working
-- at the same time whenever charcoal is being transported away (and their outputs were full)

---@param inventories NetworkedInventoriesByType
local function spreadOutputOfInventories(inventories)
    local outputInventories = concatTables(inventories.drain, inventories.io, inventories.furnace, inventories.silo)

    for _, inventory in ipairs(outputInventories) do
        spreadOutputOfInventory(inventory, inventories)
    end
end

local function main(args)
    print("[io-network v3.1.0] booting...")
    local timeout = tonumber(args[1] or 30) or 30

    while true do
        local modem = findPeripheralSide("modem")

        if not modem then
            error("no modem found")
        end

        local success, msg = pcall(function()
            local found = findInventories(modem)

            if #found > 0 then
                local inventories = readInventories(found)
                local byType = groupInventoriesByType(inventories)
                printFoundInventories(byType)
                os.sleep(1)
                spreadOutputOfInventories(byType)
            else
                print("no inventories found")
            end
        end)

        if not success then
            print(msg)

            if msg == "Terminated" then
                break
            end
        end

        print("done! sleeping for", timeout .. "s")
        waitTimeoutOrUntilKeyEvent(timeout)
    end
end

return main(arg)
