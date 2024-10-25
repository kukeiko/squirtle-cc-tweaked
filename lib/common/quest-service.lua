local Utils = require "lib.common.utils"
local Rpc = require "lib.common.rpc"
local DatabaseService = require "lib.common.database-service"

---@class QuestService : Service
local QuestService = {name = "quest", host = ""}

local function getDatabaseService()
    local databaseService = Rpc.nearest(DatabaseService)

    if not databaseService then
        error("could not connect to DatabaseService")
    end

    return databaseService
end

---@param issuedBy string
---@param type QuestType
---@return Quest
local function constructQuest(issuedBy, type)
    ---@type Quest
    local quest = {id = 0, issuedBy = issuedBy, status = "issued", type = type}

    return quest
end

---@param quest Quest
---@return Quest
local function awaitQuestCompletion(quest)
    while quest.status ~= "finished" and quest.status ~= "failed" do
        os.sleep(1)
        quest = getDatabaseService().getQuest(quest.id)
    end

    return quest
end

---@param acceptedBy string
---@param questType QuestType
---@return Quest
local function acceptQuest(acceptedBy, questType)
    local databaseService = getDatabaseService()
    local acceptedQuest = databaseService.getAcceptedQuest(acceptedBy, questType)

    if acceptedQuest then
        return acceptedQuest
    end

    local quest = databaseService.getIssuedQuest(questType)

    while not quest do
        os.sleep(1)
        quest = databaseService.getIssuedQuest(questType)
    end

    quest.acceptedBy = acceptedBy
    quest.status = "accepted"
    databaseService.updateQuest(quest)

    return quest
end

---@param issuedBy string
---@param duration integer
---@return DanceQuest
function QuestService.issueDanceQuest(issuedBy, duration)
    local databaseService = getDatabaseService()
    local quest = constructQuest(issuedBy, "dance") --[[@as DanceQuest]]
    quest.duration = duration
    quest = databaseService.createQuest(quest) --[[@as DanceQuest]]

    return quest
end

---@param issuedBy string
---@param to string[]
---@param toTag InventorySlotTag
---@param targetStock ItemStock
---@param partOfQuestId? integer
---@param label? string
---@return TransferItemsQuest
function QuestService.issueTransferItemsQuest(issuedBy, to, toTag, targetStock, partOfQuestId, label)
    local databaseService = getDatabaseService()
    local quest = constructQuest(issuedBy, "transfer-items") --[[@as TransferItemsQuest]]
    quest.to = to
    quest.toTag = toTag
    quest.items = targetStock
    quest.transferred = {}
    quest.transferredAll = false
    quest.partOfQuestId = partOfQuestId
    quest.label = label
    quest = databaseService.createQuest(quest) --[[@as TransferItemsQuest]]

    return quest
end

---@param issuedBy string
---@param item string
---@param quantity integer
---@return CraftItemQuest
function QuestService.issueCraftItemQuest(issuedBy, item, quantity)
    local databaseService = getDatabaseService()
    local quest = constructQuest(issuedBy, "craft-item") --[[@as CraftItemQuest]]
    quest.item = item
    quest.quantity = quantity
    quest = databaseService.createQuest(quest) --[[@as CraftItemQuest]]

    return quest
end

---@param partOfQuestId integer
---@param label string
---@return TransferItemsQuest?
function QuestService.findTransferItemsQuest(partOfQuestId, label)
    local databaseService = getDatabaseService()

    return Utils.find(databaseService.getQuests(), function(quest)
        return quest.type == "transfer-items" and quest.partOfQuestId == partOfQuestId and quest.label == label
    end) --[[@as TransferItemsQuest?]]
end

---@param acceptedBy string
---@return DanceQuest
function QuestService.acceptDanceQuest(acceptedBy)
    return acceptQuest(acceptedBy, "dance") --[[@as DanceQuest]]
end

---@param acceptedBy string
---@return TransferItemsQuest
function QuestService.acceptTransferItemsQuest(acceptedBy)
    return acceptQuest(acceptedBy, "transfer-items") --[[@as TransferItemsQuest]]
end

---@param acceptedBy string
---@return CraftItemQuest
function QuestService.acceptCraftItemQuest(acceptedBy)
    return acceptQuest(acceptedBy, "craft-item") --[[@as CraftItemQuest]]
end

---@param quest DanceQuest
---@return DanceQuest
function QuestService.awaitDanceQuestCompletion(quest)
    return awaitQuestCompletion(quest) --[[@as DanceQuest]]
end

---@param quest TransferItemsQuest
---@return TransferItemsQuest
function QuestService.awaitTransferItemsQuestCompletion(quest)
    return awaitQuestCompletion(quest) --[[@as TransferItemsQuest]]
end

---@param quest CraftItemQuest
---@return CraftItemQuest
function QuestService.awaitCraftItemQuestCompletion(quest)
    local foo = awaitQuestCompletion(quest) --[[@as CraftItemQuest]]

    print("sending quest", foo.id)
    return foo
end

---@param quest Quest
function QuestService.updateQuest(quest)
    local databaseService = getDatabaseService()
    databaseService.updateQuest(quest)
end

---@param id integer
function QuestService.finishQuest(id)
    local databaseService = getDatabaseService()
    local quest = databaseService.getQuest(id)
    quest.status = "finished"
    databaseService.updateQuest(quest)
end

---@param id integer
function QuestService.failQuest(id)
    local databaseService = getDatabaseService()
    local quest = databaseService.getQuest(id)
    quest.status = "failed"
    databaseService.updateQuest(quest)
end

---@param parentQuestId integer
---@return Quest[]
function QuestService.getChildQuests(parentQuestId)
    return {}
end

return QuestService
