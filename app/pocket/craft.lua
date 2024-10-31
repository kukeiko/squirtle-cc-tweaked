if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Rpc = require "lib.common.rpc"
local QuestService = require "lib.common.quest-service"
print(string.format("[craft %s]", version()))

function testCrafter()
    local questService = Rpc.tryNearest(QuestService)
    print("issuing crafting quest")
    local quest = questService.issueCraftItemQuest(os.getComputerLabel(), "minecraft:redstone_torch", 1)
    print("waiting for completion")
    quest = questService.awaitCraftItemQuestCompletion(quest)
    print("quest completed!", quest.status)
end

testCrafter()
