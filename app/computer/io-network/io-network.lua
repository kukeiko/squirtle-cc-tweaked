package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local copy = require "utils.copy"
local indexOf = require "utils.index-of"
local findPeripheralSide = require "world.peripheral.find-side"
local readInventories = require "io-network.read-inventories"
local transferItem = require "io-network.transfer-item"

---@class NetworkedInventory
---@field name string
---@field type "storage" | "io" | "output-dump" | "assigned"
-- [todo] not completely convinced that we should store ItemStacks, but instead just an integer
---@field inputStock table<string, ItemStack>
---@field inputStacks table<integer, ItemStack>
-- [todo] not completely convinced that we should store ItemStacks, but instead just an integer
---@field outputStock table<string, ItemStack>
---@field outputStacks table<integer, ItemStack>

---@class NetworkedInventoriesByType
---@field storage NetworkedInventory[]
---@field io NetworkedInventory[]
---@field assigned NetworkedInventory[]
---@field ["output-dump"] NetworkedInventory[]

---@param modem string
---@return string[]
local function findInventories(modem)
    ---@type string[]
    local chests = {}

    for _, name in pairs(peripheral.call(modem, "getNamesRemote") or {}) do
        if peripheral.hasType(name, "minecraft:chest") then
            table.insert(chests, name)
        end
    end

    return chests
end

---@param inventories NetworkedInventory[]
---@param ignore NetworkedInventory[]
---@param item string
---@return NetworkedInventory[]
local function getInventoriesAcceptingInput(inventories, ignore, item)
    local otherChests = {}

    for _, candidate in ipairs(inventories) do
        local stock = candidate.inputStock[item];

        if stock and stock.count < stock.maxCount and indexOf(ignore, candidate.name) < 1 then
            table.insert(otherChests, candidate)
        end
    end

    return otherChests
end

---@param chest NetworkedInventory
---@param chestsByType NetworkedInventoriesByType
local function spreadOutputStacksOfInventory(chest, chestsByType)
    print("working on", chest.name, "(" .. chest.type .. ")")

    for item, stock in pairs(chest.outputStock) do
        local ignore = {chest.name}

        while stock.count > 0 do
            local ioChests = getInventoriesAcceptingInput(chestsByType.io, ignore, stock.name)
            local storageChests = getInventoriesAcceptingInput(chestsByType.storage, ignore, stock.name)
            local assignedChests = getInventoriesAcceptingInput(chestsByType.assigned, ignore, stock.name)

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

            local ioAndAssignedChests = copy(ioChests)

            for i = 1, #assignedChests do
                table.insert(ioAndAssignedChests, assignedChests[i])
            end

            local inputChests = ioAndAssignedChests

            if #storageChests > 0 then
                if #ioChests > 0 then
                    -- only pick 1 storage chest in case we are spreading items across both I/O, assigned and storage chests.
                    table.insert(inputChests, storageChests[1])
                else
                    -- otherwise just spread all into storage
                    for i = 1, #storageChests do
                        table.insert(inputChests, storageChests[i])
                    end
                end
            end

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

                local transferred = transferItem(chest, inputChest, item, transfer, 8)

                if transferred < transfer then
                    -- assuming chest is full or its state changed from an external source, in which case we just ignore it
                    table.insert(ignore, inputChest.name)
                end

                stock.count = stock.count - transferred
                inputChest.inputStock[item].count = inputChest.inputStock[item].count + transferred
            end
        end
    end
end

---@param inventories NetworkedInventory[]
---@return NetworkedInventoriesByType
local function groupInventoriesByType(inventories)
    ---@type NetworkedInventoriesByType
    local inventoriesByType = {storage = {}, io = {}, ["output-dump"] = {}, assigned = {}}

    for _, inventory in ipairs(inventories) do
        table.insert(inventoriesByType[inventory.type], inventory)
    end

    return inventoriesByType
end

-- [todo] we should not only spread an item (e.g. charcoal) evenly amongst inputs,
-- but also evenly from outputs, so that e.g. the 4 lumberjack farms all start working
-- at the same time whenever charcoal is being transported away (and their outputs were full)

---@param inventories NetworkedInventory[]
local function doTheThing(inventories)
    local inventoriesByType = groupInventoriesByType(inventories)

    print("found", #inventoriesByType.io .. "x I/O,", #inventoriesByType.storage .. "x storage,",
          #inventoriesByType.assigned .. "x assigned and", #inventoriesByType["output-dump"] .. "x dumping chests")

    os.sleep(1)

    if #inventoriesByType["output-dump"] > 0 then
        print("spreading dumps...")

        for _, chest in ipairs(inventoriesByType["output-dump"]) do
            spreadOutputStacksOfInventory(chest, inventoriesByType)
        end
    end

    if #inventoriesByType.io > 0 then
        print("spreading I/O chests...")

        for i, ioChest in ipairs(inventoriesByType.io) do
            spreadOutputStacksOfInventory(ioChest, inventoriesByType)
        end
    end
end

local function main(args)
    print("[io-network v2.2.0] booting...")
    local timeout = tonumber(args[1] or 30)

    while true do
        local modem = findPeripheralSide("modem")

        if modem then
            local success, msg = pcall(function()
                local chestNames = findInventories(modem)
                local inventories = readInventories(chestNames, findPeripheralSide("minecraft:barrel"))

                doTheThing(inventories)
            end)

            if not success then
                print(msg)

                if msg == "Terminated" then
                    break
                end
            end
        end

        print("done! sleeping for", timeout .. "s")
        os.sleep(timeout)
    end
end

return main(arg)
