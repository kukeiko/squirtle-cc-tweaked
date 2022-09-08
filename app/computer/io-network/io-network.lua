package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local concatTables = require "utils.concat-tables"
local findPeripheralSide = require "world.peripheral.find-side"
local findInventories = require "io-network.find-inventories"
local readInventories = require "io-network.read-inventories"
local getInventoriesAcceptingInput = require "io-network.get-inventories-accepting-input"
local groupInventoriesByType = require "io-network.group-inventories-by-type"
local transferItem = require "inventory.transfer-item"
local printProgress = require "io-network.print-progress"

---@class NetworkedInventory
---@field type "storage" | "io" | "output-dump" | "assigned" | "furnace"
---@field name string
-- [todo] not completely convinced that we should store ItemStacks, but instead just an integer
-- [update] nope, has to be ItemStack as we're mutating the stock within transferItem()
---@field inputStock table<string, ItemStack>
---@field inputStacks table<integer, ItemStack>
-- [todo] not completely convinced that we should store ItemStacks, but instead just an integer
-- [update] nope, has to be ItemStack as we're mutating the stock within transferItem()
---@field outputStock table<string, ItemStack>
---@field outputStacks table<integer, ItemStack>

---@class NetworkedInventoriesByType
---@field storage NetworkedInventory[]
---@field io NetworkedInventory[]
---@field assigned NetworkedInventory[]
---@field ["output-dump"] NetworkedInventory[]
---@field furnace NetworkedInventory[]

---@class FoundInventory
---@field name string
---@field type string

---@param chest NetworkedInventory
---@param inventoriesByType NetworkedInventoriesByType
local function spreadOutputStacksOfInventory(chest, inventoriesByType)
    print("working on", chest.name, "(" .. chest.type .. ")")

    for item, stock in pairs(chest.outputStock) do
        local ignore = {chest.name}

        while stock.count > 0 do
            local ioChests = getInventoriesAcceptingInput(inventoriesByType.io, ignore, stock.name)
            local storageChests = getInventoriesAcceptingInput(inventoriesByType.storage, ignore, stock.name)
            local assignedChests = getInventoriesAcceptingInput(inventoriesByType.assigned, ignore, stock.name)
            local furnaces = getInventoriesAcceptingInput(inventoriesByType.furnace, ignore, stock.name)

            print(stock.count .. "x", item, "across:")

            if #ioChests > 0 then
                print(" - ", #ioChests .. "x io chests")
            end

            if #storageChests > 0 then
                print(" - ", #storageChests .. "x storage chests")
            end

            if #assignedChests > 0 then
                print(" - ", #assignedChests .. "x assigned chests")
            end

            if #furnaces > 0 then
                print(" - ", #furnaces .. "x furnaces")
            end

            ---@type NetworkedInventory[]
            local inputChests = concatTables(ioChests, assignedChests, furnaces, storageChests)

            if #inputChests == 0 then
                print(" - (no chests)")
                break
            end

            local stockPerChest = math.floor(stock.count / #inputChests)
            local rest = stock.count - stockPerChest

            for i, inputChest in ipairs(inputChests) do
                local transfer = stockPerChest

                if i <= rest then
                    transfer = transfer + 1
                end

                ---@type Inventory
                local fromInventory = {name = chest.name, stacks = chest.outputStacks, stock = chest.outputStock}
                ---@type Inventory
                local toInventory = {
                    name = inputChest.name,
                    stacks = inputChest.inputStacks,
                    stock = inputChest.inputStock
                }

                local transferred = transferItem(fromInventory, toInventory, item, transfer, 8)

                if transferred < transfer then
                    -- assuming chest is full or its state changed from an external source, in which case we just ignore it
                    table.insert(ignore, inputChest.name)
                end
            end
        end
    end
end

-- [todo] we should not only spread an item (e.g. charcoal) evenly amongst inputs,
-- but also evenly from outputs, so that e.g. the 4 lumberjack farms all start working
-- at the same time whenever charcoal is being transported away (and their outputs were full)

---@param inventories NetworkedInventory[]
local function doTheThing(inventories)
    local inventoriesByType = groupInventoriesByType(inventories)

    print("found:")
    local numIo = #inventoriesByType.io
    local numStorage = #inventoriesByType.storage
    local numAssigned = #inventoriesByType.assigned
    local numDumps = #inventoriesByType["output-dump"]
    local numFurnaces = #inventoriesByType.furnace

    if numIo > 0 then
        print(" - " .. numIo .. "x I/O")
    end

    if numStorage > 0 then
        print(" - " .. numStorage .. "x Storage")
    end

    if numAssigned > 0 then
        print(" - " .. numAssigned .. "x Assigned")
    end

    if numDumps > 0 then
        print(" - " .. numDumps .. "x Dump")
    end

    if numFurnaces > 0 then
        print(" - " .. numFurnaces .. "x Furnace")
    end

    os.sleep(1)

    if #inventoriesByType["output-dump"] > 0 then
        print("spreading dumps...")

        for _, chest in ipairs(inventoriesByType["output-dump"]) do
            spreadOutputStacksOfInventory(chest, inventoriesByType)
        end
    end

    if #inventoriesByType.io > 0 then
        print("spreading I/O chests...")

        for _, ioChest in ipairs(inventoriesByType.io) do
            spreadOutputStacksOfInventory(ioChest, inventoriesByType)
        end
    end

    if #inventoriesByType.furnace > 0 then
        print("spreading furnaces...")

        for _, furnace in ipairs(inventoriesByType.furnace) do
            spreadOutputStacksOfInventory(furnace, inventoriesByType)
        end
    end
end

local function main(args)
    print("[io-network v2.3.0] booting...")
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
