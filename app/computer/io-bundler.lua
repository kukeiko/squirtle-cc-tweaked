package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Modem = require "world.modem"
local Chest = require "world.chest"

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
local function transferToOtherChest(from, to, fromOutputStacks)
    local inputStacks = Chest.getInputStacks(to, true)

    for inputSlot, inputStack in pairs(inputStacks) do
        for outputSlot, outputStack in pairs(fromOutputStacks) do
            if outputStack.name == inputStack.name and outputStack.count > 1 and inputStack.count < inputStack.maxCount then
                local transfer = math.min(outputStack.count - 1, inputStack.maxCount - inputStack.count)

                print("move", from, to, outputSlot, transfer, inputSlot)
                local transferred = Chest.pushItems(from, to, outputSlot, transfer, inputSlot)

                inputStack.count = inputStack.count + transferred
                outputStack.count = outputStack.count - transferred
            end
        end
    end
end

---@param chests string[]
local function transferBetweenChests(chests)
    for _, chest in pairs(chests) do
        local outputStacks = Chest.getOutputStacks(chest)

        for _, otherChest in pairs(otherChests(chest, chests)) do
            transferToOtherChest(chest, otherChest, outputStacks)
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

-- [todo] crashes if player accidentally clicks modems
local function main(args)
    local modem = Peripheral.findSide("modem")

    if not modem then
        error("no modem found")
    end

    local chests = getRemoteChestNames(modem)
    Utils.prettyPrint(chests)

    while true do
        transferBetweenChests(chests)
        print("sleepy 3s...")
        os.sleep(3)
    end
end

return main(arg)
