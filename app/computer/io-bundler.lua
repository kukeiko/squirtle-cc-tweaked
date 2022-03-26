package.path = package.path .. ";/lib/?.lua"

local Utils = require "utils"
local Peripheral = require "world.peripheral"
local Modem = require "world.modem"
local Chest = require "world.chest"

local function printUsage()
    print("Usage:")
    print("io-bundler <main-chest-name>")
end

local function main(args)
    local mainChest = args[1]

    if type(mainChest) ~= "string" then
        return printUsage()
    end

    local modem = Peripheral.findSide("modem")

    if not modem then
        error("no modem found")
    end

    ---@type table<string, string>
    local auxChests = {}

    for _, name in pairs(Modem.getNamesRemote(modem) or {}) do
        local types = Modem.getTypeRemote(modem, name)

        for _, type in pairs(types) do
            if (type == "minecraft:trapped_chest" or type == "minecraft:chest") and name ~= mainChest then
                auxChests[name] = type
                break
            end
        end
    end

    Utils.prettyPrint(auxChests)

    while true do
        for auxChest, chestType in pairs(auxChests) do
            ---@type table<integer, ItemStackV2>
            local outputStacks

            if chestType == "minecraft:trapped_chest" then
                outputStacks = Chest.getOutputStacks(auxChest)
            else
                outputStacks = Chest.getStacks(auxChest)
            end

            for otherAuxChest, otherType in pairs(auxChests) do
                if otherAuxChest ~= auxChest and otherType == "minecraft:trapped_chest" then
                    local inputStacks = Chest.getInputStacks(otherAuxChest, true)

                    for inputSlot, inputStack in pairs(inputStacks) do
                        if inputStack.count < inputStack.maxCount then
                            for outputSlot, outputStack in pairs(outputStacks) do
                                if outputStack.name == inputStack.name and outputStack.count > 1 and inputStack.count <
                                    inputStack.maxCount then
                                    local transfer = math.min(outputStack.count - 1,
                                                              inputStack.maxCount - inputStack.count)

                                    print("move", auxChest, otherAuxChest, outputSlot, transfer, inputSlot)
                                    Utils.waitForUserToHitEnter()
                                    local transferred = Chest.pushItems_V2(auxChest, otherAuxChest, outputSlot,
                                                                           transfer, inputSlot)

                                    inputStack.count = inputStack.count + transferred
                                    outputStack.count = outputStack.count - transferred
                                end
                            end
                        end
                    end
                end
            end

            -- [todo] naming it "input" on purpose. a hint that IO system revision is necessary
            -- (if it is possible what i have in mind, which is just flipping input w/ output at the main chest)
            local mainChestInputStacks = Chest.getOutputStacks(mainChest, true)

            for inputSlot, inputStack in pairs(mainChestInputStacks) do
                if inputStack.count < inputStack.maxCount then
                    for outputSlot, outputStack in pairs(outputStacks) do
                        if outputStack.name == inputStack.name and outputStack.count > 1 and inputStack.count <
                            inputStack.maxCount then
                            local transfer = math.min(outputStack.count - 1, inputStack.maxCount - inputStack.count)

                            print("move", auxChest, mainChest, outputSlot, transfer, inputSlot)
                            Utils.waitForUserToHitEnter()
                            local transferred = Chest.pushItems_V2(auxChest, mainChest, outputSlot, transfer, inputSlot)

                            inputStack.count = inputStack.count + transferred
                            outputStack.count = outputStack.count - transferred
                        end
                    end
                end
            end
        end

        -- [todo] naming it "output" on purpose. a hint that IO system revision is necessary
        -- (if it is possible what i have in mind, which is just flipping input w/ output at the main chest)
        local mainChestOutputStacks = Chest.getInputStacks(mainChest, true)

        for auxChest, auxChestType in pairs(auxChests) do
            if auxChestType == "minecraft:trapped_chest" then
                local inputStacks = Chest.getInputStacks(auxChest, true)

                for inputSlot, inputStack in pairs(inputStacks) do
                    if inputStack.count < inputStack.maxCount then
                        for outputSlot, outputStack in pairs(mainChestOutputStacks) do
                            if outputStack.name == inputStack.name and outputStack.count > 1 and inputStack.count <
                                inputStack.maxCount then
                                local transfer = math.min(outputStack.count - 1, inputStack.maxCount - inputStack.count)

                                print("move", mainChest, auxChest, outputSlot, transfer, inputSlot)
                                Utils.waitForUserToHitEnter()
                                local transferred = Chest.pushItems_V2(mainChest, auxChest, outputSlot, transfer,
                                                                       inputSlot)

                                inputStack.count = inputStack.count + transferred
                                outputStack.count = outputStack.count - transferred
                            end
                        end
                    end
                end
            end
        end

        print("sleepy 3s...")
        os.sleep(3)
    end
end

return main(arg)
