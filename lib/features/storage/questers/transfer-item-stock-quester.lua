local Utils = require "lib.common.utils"
local ItemStock = require "lib.common.models.item-stock"
local Rpc = require "lib.common.rpc"
local StorageService = require "lib.features.storage.storage-service"
local QuestService = require "lib.common.quest-service"

---@param quest TransferItemsQuest
---@param storageService StorageService|RpcClient
---@return ItemStock
local function fillBuffer(quest, storageService)
    local bufferStock = storageService.getBufferStock(quest.bufferId)
    local openStock = ItemStock.subtract(quest.items, bufferStock)

    if not Utils.isEmpty(openStock) then
        -- print("transfer stock to buffer...")
        storageService.transferStockToBuffer(quest.bufferId, openStock)
    end

    return storageService.getBufferStock(quest.bufferId)
end

---@param quest TransferItemsQuest
---@param storageService StorageService|RpcClient
---@param questService QuestService|RpcClient
local function updateTransferred(quest, storageService, questService)
    local bufferStock = storageService.getBufferStock(quest.bufferId)
    local transferred = ItemStock.subtract(quest.found, bufferStock)
    quest.transferred = transferred
    quest.transferredAll = Utils.isEmpty(ItemStock.subtract(quest.items, transferred))
    questService.updateQuest(quest)
end

---@param quest TransferItemsQuest
---@param storageService StorageService|RpcClient
---@param questService QuestService|RpcClient
local function emptyBuffer(quest, storageService, questService)
    -- print("transfer stock from buffer to target...")
    ---@type ItemStock
    storageService.transferBufferStock(quest.bufferId, quest.to, quest.toTag)
    updateTransferred(quest, storageService, questService)

    local bufferStock = storageService.getBufferStock(quest.bufferId)

    if not Utils.isEmpty(bufferStock) then
        -- print("trying to empty out the buffer...")

        while not Utils.isEmpty(bufferStock) do
            os.sleep(1)
            storageService.transferBufferStock(quest.bufferId, quest.to, quest.toTag)
            updateTransferred(quest, storageService, questService)
            bufferStock = storageService.getBufferStock(quest.bufferId)
        end

        -- print("managed to empty out buffer!")
    end
end

-- [todo] if it crashes, any allocated buffers need to be cleaned out
return function()
    local questService = Rpc.nearest(QuestService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        print("[wait] for new quest...")
        local quest = questService.acceptTransferItemsQuest(os.getComputerLabel())
        print("[found] new quest!", quest.id)
        -- [todo] hardcoded slotCount
        local bufferId = quest.bufferId or storageService.allocateQuestBuffer(quest)

        if not quest.bufferId then
            quest.bufferId = bufferId
            questService.updateQuest(quest)
        end

        if not quest.found then
            quest.found = fillBuffer(quest, storageService)
            questService.updateQuest(quest)
        end

        emptyBuffer(quest, storageService, questService)
        print("[finish] quest!", quest.id)
        questService.finishQuest(quest.id)
        storageService.freeBuffer(bufferId)
    end
end
