local DatabaseService = require "lib.common.database-service"

---@class QuestService : Service
local QuestService = {name = "quest", host = ""}

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
        quest = DatabaseService.getQuest(quest.id)
    end

    return quest
end

---@param acceptedBy string
---@param questType QuestType
---@return Quest
local function acceptQuest(acceptedBy, questType)
    local acceptedQuest = DatabaseService.getAcceptedQuest(acceptedBy, questType)

    if acceptedQuest then
        return acceptedQuest
    end

    local quest = DatabaseService.getIssuedQuest(questType)

    while not quest do
        os.sleep(1)
        quest = DatabaseService.getIssuedQuest(questType)
    end

    quest.acceptedBy = acceptedBy
    quest.status = "accepted"
    DatabaseService.updateQuest(quest)

    return quest
end

---@param issuedBy string
---@param duration integer
---@return DanceQuest
function QuestService.issueDanceQuest(issuedBy, duration)
    local quest = constructQuest(issuedBy, "dance") --[[@as DanceQuest]]
    quest.duration = duration
    quest = DatabaseService.createQuest(quest) --[[@as DanceQuest]]

    return quest
end

---@param issuedBy string
---@param to string[]
---@param toTag InventorySlotTag
---@param targetStock ItemStock
---@return TransferItemsQuest
function QuestService.issueTransferItemsQuest(issuedBy, to, toTag, targetStock)
    local quest = constructQuest(issuedBy, "transfer-items") --[[@as TransferItemsQuest]]
    quest.to = to
    quest.toTag = toTag
    quest.items = targetStock
    quest.transferred = {}
    quest.transferredAll = false
    quest = DatabaseService.createQuest(quest) --[[@as TransferItemsQuest]]

    return quest
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

---@param quest Quest
function QuestService.updateQuest(quest)
    DatabaseService.updateQuest(quest)
end

---@param id integer
function QuestService.finishQuest(id)
    local quest = DatabaseService.getQuest(id)
    quest.status = "finished"
    DatabaseService.updateQuest(quest)
end

---@param id integer
function QuestService.failQuest(id)
    local quest = DatabaseService.getQuest(id)
    quest.status = "failed"
    DatabaseService.updateQuest(quest)
end

---@param parentQuestId integer
---@return Quest[]
function QuestService.getChildQuests(parentQuestId)
    return {}
end

return QuestService
