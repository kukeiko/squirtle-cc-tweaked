package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/computer/?.lua"

local copy = require "utils.copy"
local indexOf = require "utils.index-of"
local findPeripheralSide = require "world.peripheral.find-side"
local readNetworkedChests = require "io-network.read-networked-chests"
local transferItem = require "io-network.transfer-item"

---@class NetworkedChest
---@field name string
---@field type "storage" | "io" | "output-dump" | "assigned"
---@field inputStock table<string, ItemStack>
---@field inputStacks table<integer, ItemStack>
---@field outputStock table<string, ItemStack>
---@field outputStacks table<integer, ItemStack>

---@class NetworkedChestsByType
---@field storage NetworkedChest[]
---@field io NetworkedChest[]
---@field assigned NetworkedChest[]
---@field ["output-dump"] NetworkedChest[]

---@param modem string
---@return string[]
local function findNetworkedChests(modem)
    ---@type string[]
    local chests = {}

    for _, name in pairs(peripheral.call(modem, "getNamesRemote") or {}) do
        if peripheral.hasType(name, "minecraft:chest") then
            table.insert(chests, name)
        end
    end

    return chests
end

---@param chests NetworkedChest[]
---@param ignore NetworkedChest[]
---@param item string
---@return NetworkedChest[]
local function getChestsAcceptingInput(chests, ignore, item)
    local otherChests = {}

    for _, candidate in ipairs(chests) do
        local stock = candidate.inputStock[item];

        if stock and stock.count < stock.maxCount and indexOf(ignore, candidate.name) < 1 then
            table.insert(otherChests, candidate)
        end
    end

    return otherChests
end

---@param chest NetworkedChest
---@param chestsByType NetworkedChestsByType
local function spreadChestOutput(chest, chestsByType)
    print("working on", chest.name, "(" .. chest.type .. ")")

    for item, stock in pairs(chest.outputStock) do
        local ignore = {chest.name}

        while stock.count > 0 do
            local ioChests = getChestsAcceptingInput(chestsByType.io, ignore, stock.name)
            local storageChests = getChestsAcceptingInput(chestsByType.storage, ignore, stock.name)
            local assignedChests = getChestsAcceptingInput(chestsByType.assigned, ignore, stock.name)

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
                    table.insert(inputChests, storageChests[1])
                else
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

---@param chests NetworkedChest[]
---@return NetworkedChestsByType
local function groupChestsByType(chests)
    ---@type NetworkedChestsByType
    local chestsByType = {storage = {}, io = {}, ["output-dump"] = {}, assigned = {}}

    for _, networkedChest in ipairs(chests) do
        table.insert(chestsByType[networkedChest.type], networkedChest)
    end

    return chestsByType
end

-- [todo] we should not only spread an item (e.g. charcoal) evenly amongst inputs,
-- but also evenly from outputs, so that e.g. the 4 lumberjack farms all start working
-- at the same time whenever charcoal is being transported away (and their outputs were full)

---@param networkedChests NetworkedChest[]
local function doTheThing(networkedChests)
    local chestsByType = groupChestsByType(networkedChests)

    print("found", #chestsByType.io .. "x I/O,", #chestsByType.storage .. "x storage,",
          #chestsByType.assigned .. "x assigned and ", #chestsByType["output-dump"] .. "x dumping chests")

    os.sleep(1)

    if #chestsByType["output-dump"] > 0 then
        print("spreading dumps...")

        for _, chest in ipairs(chestsByType["output-dump"]) do
            spreadChestOutput(chest, chestsByType)
        end
    end

    if #chestsByType.io > 0 then
        print("spreading I/O chests...")

        for i, ioChest in ipairs(chestsByType.io) do
            spreadChestOutput(ioChest, chestsByType)
        end
    end
end

local function main(args)
    print("[io-network v2.0.0] booting...")
    local timeout = tonumber(args[1] or 30)

    while true do
        local modem = findPeripheralSide("modem")

        if modem then
            local success, msg = pcall(function()
                local chestNames = findNetworkedChests(modem)
                local networkedChests = readNetworkedChests(chestNames, findPeripheralSide("minecraft:barrel"))

                doTheThing(networkedChests)
            end)

            if not success then
                print(msg)
            end
        end

        print("done! sleeping for", timeout .. "s")
        -- break
        os.sleep(timeout)
    end
end

return main(arg)
