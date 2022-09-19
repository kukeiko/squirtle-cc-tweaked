package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local concatTables = require "utils.concat-tables"
local findPeripheralSide = require "world.peripheral.find-side"
local findInventories = require "io-network.find-inventories"
local readInventories = require "io-network.read-inventories"
local groupInventoriesByType = require "io-network.group-inventories-by-type"
local printProgress = require "io-network.print-progress"
local spreadOutputOfInventory = require "io-network.spread-output-of-inventory"

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

---@param inventories NetworkedInventory[]
local function doTheThing(inventories)
    local byType = groupInventoriesByType(inventories)

    print("found:")
    local numIo = #byType.io
    local numStorage = #byType.storage
    local numDrains = #byType.drain
    local numFurnaces = #byType.furnace
    local numSilos = #byType.silo

    if numIo > 0 then
        print(" - " .. numIo .. "x I/O")
    end

    if numStorage > 0 then
        print(" - " .. numStorage .. "x Storage")
    end

    if numDrains > 0 then
        print(" - " .. numDrains .. "x Drain")
    end

    if numFurnaces > 0 then
        print(" - " .. numFurnaces .. "x Furnace")
    end

    if numSilos > 0 then
        print(" - " .. numSilos .. "x Silo")
    end

    os.sleep(1)

    local outputInventories = concatTables(byType.drain, byType.io, byType.furnace, byType.silo)

    for _, inventory in ipairs(outputInventories) do
        spreadOutputOfInventory(inventory, byType)
    end
end

local function main(args)
    print("[io-network v3.1.0] booting...")
    local timeout = tonumber(args[1] or 30)

    while true do
        local modem = findPeripheralSide("modem")

        if modem then
            local success, msg = pcall(function()
                local found = findInventories(modem)

                if #found > 0 then
                    local inventories = readInventories(found)
                    doTheThing(inventories)
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
        end

        print("done! sleeping for", timeout .. "s")
        local steps = 10
        local x, y = printProgress(0, steps)

        parallel.waitForAny(function()
            local timeoutTick = timeout / steps

            for i = 1, steps do
                os.sleep(timeoutTick)
                printProgress(i, steps, x, y)
            end
        end, function()
            os.pullEvent("key")
            printProgress(steps, steps, x, y)
        end)
    end
end

return main(arg)
