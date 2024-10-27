if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.common.utils"
local EventLoop = require "lib.common.event-loop"
local Rpc = require "lib.common.rpc"
local CrafterService = require "lib.features.crafter-service"
local DatabaseService = require "lib.common.database-service"
local StorageService = require "lib.features.storage.storage-service"
local QuestService = require "lib.common.quest-service"

print(string.format("[io-crafter %s] booting...", version()))

---@return QuestService|RpcClient, DatabaseService|RpcClient, StorageService|RpcClient
local function connect()
    local questService = Rpc.nearest(QuestService)

    if not questService then
        error("could not connect to QuestService")
    end

    local databaseService = Rpc.nearest(DatabaseService)

    if not databaseService then
        error("could not connect to DatabaseService")
    end

    local storageService = Rpc.nearest(StorageService)

    if not storageService then
        error("could not connect to StorageService")
    end

    return questService, databaseService, storageService
end

---@param quest CraftItemQuest
---@param questService QuestService|RpcClient
---@param storageService StorageService|RpcClient
---@param databaseService DatabaseService|RpcClient
---@return CraftingDetails
local function initCraftingDetails(quest, questService, storageService, databaseService)
    ---@type ItemStock
    local targetStock = {[quest.item] = quest.quantity}
    local storageStock = storageService.getStock()
    storageStock[quest.item] = nil
    local recipes = databaseService.getCraftingRecipes()
    quest.craftingDetails = CrafterService.getCraftingDetails(targetStock, storageStock, Utils.toMap(recipes, "item"))
    questService.updateQuest(quest)

    return quest.craftingDetails
end

---@param quest CraftItemQuest
---@param questService QuestService|RpcClient
---@param storageService StorageService|RpcClient
---@return integer
local function allocateBuffer(quest, questService, storageService)
    -- [todo] hardcoded slotCount
    quest.bufferId = storageService.allocateQuestBuffer(quest)
    questService.updateQuest(quest)
    print("allocated new buffer", quest.bufferId)

    return quest.bufferId
end

---@param quest CraftItemQuest
---@param items ItemStock
---@param buffer string[]
---@param questService QuestService|RpcClient
---@return TransferItemsQuest
local function getOrIssueTransferIngredientsQuest(quest, items, buffer, questService)
    local label = "transfer-ingredients"
    -- [todo] what if quest is already finished?
    local transferQuest = questService.findTransferItemsQuest(quest.id, label)

    if not transferQuest then
        transferQuest = questService.issueTransferItemsQuest(os.getComputerLabel(), buffer, "buffer", items, quest.id, label)
        print("issued transfer items quest!")
    end

    return transferQuest
end

---@param usedRecipe UsedCraftingRecipe
local function usedRecipeToItemStock(usedRecipe)
    ---@type ItemStock
    local stock = {}

    for item, slots in pairs(usedRecipe.ingredients) do
        stock[item] = (stock[item] or 0) + (#slots * usedRecipe.timesUsed)
    end

    return stock
end

---@param recipe UsedCraftingRecipe
---@param bufferId integer
---@param storageService StorageService|RpcClient
local function craft(recipe, bufferId, storageService)
    local stash = storageService.getStashName(os.getComputerLabel())
    local ingredients = usedRecipeToItemStock(recipe)
    -- [todo] assert that everything got transferred
    storageService.transferBufferStock(bufferId, {stash}, "buffer", ingredients)
    -- [todo] move craft() into this file
    CrafterService.craft(recipe, recipe.timesUsed)
    -- [todo] assert that everything got transferred
    storageService.transferInventoryStockToBuffer(bufferId, stash, "buffer")
end

EventLoop.run(function()
    while true do
        local questService, databaseService, storageService = connect()
        print("[wait] for new quest...")
        local quest = questService.acceptCraftItemQuest(os.getComputerLabel())
        print("[yay] got a quest!")
        local craftingDetails = quest.craftingDetails or initCraftingDetails(quest, questService, storageService, databaseService)

        if not Utils.isEmpty(craftingDetails.unavailable) then
            questService.failQuest(quest.id)
            -- [todo] should not error out, just break/return/...
            error("missing ingredients in storage")
        end

        local bufferId = quest.bufferId or allocateBuffer(quest, questService, storageService)
        local buffer = storageService.getBufferNames(bufferId)
        local transferIngredientsQuest = getOrIssueTransferIngredientsQuest(quest, craftingDetails.available, buffer, questService)
        transferIngredientsQuest = questService.awaitTransferItemsQuestCompletion(transferIngredientsQuest)

        if not transferIngredientsQuest.transferredAll then
            -- [todo] flush buffer back to storage
            questService.failQuest(quest.id)
            -- [todo] should not error out, just break/return/...
            error("did not manage to fetch all ingredients")
        end

        local usedRecipes = quest.usedRecipes or Utils.clone(craftingDetails.usedRecipes)

        while #usedRecipes > 0 do
            craft(usedRecipes[1], bufferId, storageService)
            table.remove(usedRecipes, 1)
            quest.usedRecipes = usedRecipes
            questService.updateQuest(quest)
        end

        storageService.flushBuffer(bufferId)
        storageService.freeBuffer(bufferId)
        questService.finishQuest(quest.id)
    end
end)

