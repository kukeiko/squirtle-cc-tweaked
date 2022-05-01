package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Modem = require "world.modem"
local Chest = require "world.chest"
local timeout = 7

---@param self string
---@param all string[]
---@return string[] others
local function otherChests(self, all)
    ---@type string[]
    local others = {}

    for i = 1, #all do
        if all[i] ~= self then
            table.insert(others, all[i])
        end
    end

    return others
end

---@param from string|integer
---@param to string|integer
---@param fromOutputStacks table<integer, ItemStack>
local function transferToOtherChest(from, to, fromOutputStacks, transferAll)
    transferAll = transferAll or false

    -- local inputStacks = Chest.getInputStacks(to, true)
    local inputStacks = Chest.getInputStacks(to)

    for inputSlot, inputStack in pairs(inputStacks) do
        for outputSlot, outputStack in pairs(fromOutputStacks) do
            -- if outputStack.name == inputStack.name and outputStack.count > 1 and inputStack.count < inputStack.maxCount then
            if outputStack.name == inputStack.name and outputStack.count > 0 and inputStack.count <
                (inputStack.maxCount or 64) then
                local outputTransfer = outputStack.count - 1

                if transferAll then
                    outputTransfer = outputStack.count
                end

                if outputTransfer > 0 then
                    local transfer = math.min(outputTransfer, (inputStack.maxCount or 64) - inputStack.count)
                    print("move", from, to, outputSlot, transfer, inputSlot)
                    local transferred = Chest.pushItems(from, to, outputSlot, transfer, inputSlot)

                    inputStack.count = inputStack.count + transferred
                    outputStack.count = outputStack.count - transferred
                end
            end
        end
    end
end

---@param chests string[]
---@param dumpingChests table<string, unknown>
local function transferBetweenChests(chests, dumpingChests)
    for _, chest in pairs(chests) do
        if not dumpingChests[chest] then
            local outputStacks = Chest.getOutputStacks(chest)

            if not Utils.isEmpty(outputStacks) then
                print("spread output of", chest)
                for _, otherChest in pairs(otherChests(chest, chests)) do
                    transferToOtherChest(chest, otherChest, outputStacks)
                end
            end
        end
    end
end

---@param modem string|integer
---@return string[]
local function getRemoteChestNames(modem)
    ---@type string[]
    local chests = {}

    for _, name in pairs(Modem.getNamesRemote(modem) or {}) do
        if Chest.isChestType(Modem.getTypeRemote(modem, name)) then
            table.insert(chests, name)
        end
    end

    return chests
end

local function main(args)
    print("[io-bundler v1.5.0] booting...")
    local modem = Peripheral.findSide("modem")

    if not modem then
        error("no modem found")
    end

    ---@type table<string, unknown>
    local dumpingChests = {}

    for i = 1, #args do
        dumpingChests[args[i]] = true
    end

    while true do
        local modem = Peripheral.findSide("modem")

        if modem then
            local success, msg = pcall(function()
                local chests = getRemoteChestNames(modem)
                table.sort(chests)
                print("syncing", #chests, "connected chests")
                transferBetweenChests(chests, dumpingChests)

                for chest in pairs(dumpingChests) do
                    local outputDumpStacks = Chest.getOutputStacks(chest)

                    if not Utils.isEmpty(outputDumpStacks) then
                        print("spreading player input dump", chest)
                        for _, otherChest in pairs(otherChests(chest, chests)) do
                            transferToOtherChest(chest, otherChest, outputDumpStacks, true)
                        end
                    end
                end
            end)

            if not success then
                print(msg)
            end
        end

        os.sleep(timeout)
    end
end

return main(arg)
