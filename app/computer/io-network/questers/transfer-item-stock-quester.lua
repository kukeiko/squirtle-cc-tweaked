local Utils = require "lib.common.utils"
local ItemStock = require "lib.common.models.item-stock"
local Rpc = require "lib.rpc"
local StorageService = require "lib.services.storage-service"
local QuestService = require "lib.common.quest-service"

return function()
    local questService = Rpc.nearest(QuestService)
    local storageService = Rpc.nearest(StorageService)

    while true do
        local quest = questService.acceptTransferItemsQuest(os.getComputerLabel())
        -- [todo] hardcoded slotCount
        local bufferId = quest.bufferId or storageService.allocateQuestBuffer(quest)

        if not quest.bufferId then
            quest.bufferId = bufferId
            questService.updateQuest(quest)
        end

        local bufferStock = storageService.getBufferStock(bufferId)
        local openStock = ItemStock.subtract(quest.items, bufferStock)

        if not Utils.isEmpty(openStock) then
            storageService.transferStockToBuffer(bufferId, openStock)
        end

        quest.found = storageService.getBufferStock(bufferId)
        questService.updateQuest(quest)

        -- [todo] what if buffer could not be emptied?
        local transferred = storageService.transferBufferStock(bufferId, quest.to, quest.toTag)
        quest.transferred = transferred
        quest.transferredAll = Utils.isEmpty(ItemStock.subtract(quest.items, transferred))
        questService.updateQuest(quest)
        questService.finishQuest(quest.id)
        -- [todo] test that "free buffer" is working
        storageService.freeBuffer(bufferId)
    end
end
