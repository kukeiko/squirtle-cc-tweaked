local Utils = require "lib.tools.utils"
local CraftingRecipe = require "lib.inventory.crafting-recipe"

---@class CraftingApi
local CraftingApi = {}

---@param recipe CraftingRecipe
---@param recipes CraftingRecipes
---@return string[]
function CraftingApi.getIngredients(recipe, recipes)
    return CraftingRecipe.getIngredients(recipe, recipes)
end

---Given an item, returns the maximum number of times it could be crafted based on what is available in storedStock,
---ignoring that ingredients might be used by multiple items within the recipe tree of the item (hence "optimistic").
---Used to determine the upper bound for the binary search in getCraftableCount() as an optimization step.
---@param item string
---@param storedStock ItemStock
---@param recipes CraftingRecipes
---@param blacklist? string[]
---@return integer
local function getOptimisticCraftableCount(item, storedStock, recipes, blacklist)
    blacklist = Utils.copy(blacklist or {})
    table.insert(blacklist, item)
    local recipe = recipes[item]
    local stored = storedStock[item] or 0

    if not recipe then
        return stored
    end

    ---@type integer?
    local lowest

    for ingredient, ingredientSlots in pairs(recipe.ingredients) do
        if not Utils.indexOf(blacklist, ingredient) then
            local crafted = math.floor(getOptimisticCraftableCount(ingredient, storedStock, recipes, blacklist) / #ingredientSlots)
            local available = stored + (crafted * recipe.quantity)

            if lowest == nil or available < lowest then
                lowest = available
            end
        end
    end

    return lowest or stored
end

---@param item string
---@param storedStock ItemStock
---@param recipes CraftingRecipes
---@param blacklist? string[]
---@return integer
function CraftingApi.getCraftableCount(item, storedStock, recipes, blacklist)
    local low, high = 0, getOptimisticCraftableCount(item, storedStock, recipes, blacklist)
    high = high - (storedStock[item] or 0)

    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        local craftingDetails = CraftingApi.getCraftingDetails({[item] = mid}, storedStock, recipes)

        if Utils.isEmpty(craftingDetails.unavailable) then
            low = mid
        else
            high = mid - 1
        end
    end

    return low
end

---[todo] "recipes" argument should instead just be CraftingRecipe[]
---[todo] throw error if targetStock contains items for which there are no recipes
---@param items ItemStock
---@param storage ItemStock
---@param recipes table<string, CraftingRecipe>
---@return CraftingDetails
function CraftingApi.getCraftingDetails(items, storage, recipes)
    ---@type ItemStock
    local expandedStock = {}
    ---@type ItemStock
    local unavailableStock = {}
    ---@type ItemStock
    local craftedLeftoverStock = {}
    ---@type UsedCraftingRecipe[]
    local usedRecipes = {}
    ---@type ItemStock
    local mutatedStorage = {}

    ---@param item string
    ---@param openQuantity integer
    ---@param blacklist string[]
    ---@param isRootRecipe boolean
    local function recurse(item, openQuantity, blacklist, isRootRecipe)
        blacklist = Utils.copy(blacklist or {})
        table.insert(blacklist, item)

        if craftedLeftoverStock[item] then
            -- reuse items from a previous craft that resulted in more items than needed (e.g. wanted 3x sticks, but recipe creates 4x => 1x leftover) 
            local availableLeftOver = craftedLeftoverStock[item]
            craftedLeftoverStock[item] = math.max(0, availableLeftOver - openQuantity)
            openQuantity = math.max(0, openQuantity - availableLeftOver)
        end

        local available = 0

        if not isRootRecipe then
            -- reuse items from storage if we're allowed to and they exist.
            -- keep track of taken items in the expandedStock, and only change mutatedStorage to take from instead of affecting the original storage.
            available = math.min(mutatedStorage[item] or storage[item] or 0, openQuantity)

            if available > 0 then
                mutatedStorage[item] = (mutatedStorage[item] or storage[item]) - available
                expandedStock[item] = (expandedStock[item] or 0) + available
            end
        end

        if available >= openQuantity then
            -- if there's enough in the storage, we don't have to craft anything
            return
        end

        local open = openQuantity - available
        local recipe = recipes[item]

        -- only if there is a crafting recipe for the item and all its ingredients are not on the blacklist may we craft it.
        -- the blacklist serves to prevent endless recursion in cases like Iron Block > Iron Ingot > Iron Block > Iron Ingot etc.
        if recipe and Utils.every(recipe.ingredients, function(_, ingredient)
            return not Utils.indexOf(blacklist, ingredient)
        end) then
            local timesCrafted = math.ceil(open / recipe.quantity)
            local craftedQuantity = timesCrafted * recipe.quantity
            ---@type UsedCraftingRecipe
            local usedRecipe = {
                ingredients = recipe.ingredients,
                item = recipe.item,
                quantity = recipe.quantity,
                timesUsed = timesCrafted,
                isRoot = isRootRecipe
            }
            table.insert(usedRecipes, usedRecipe)

            if craftedQuantity > open then
                craftedLeftoverStock[item] = (craftedLeftoverStock[item] or 0) + (craftedQuantity - open)
            end

            for ingredient, ingredientSlots in pairs(recipe.ingredients) do
                recurse(ingredient, #ingredientSlots * timesCrafted, blacklist, false)
            end
        else
            unavailableStock[item] = (unavailableStock[item] or 0) + open
        end
    end

    for item, quantity in pairs(items) do
        recurse(item, quantity, {}, true)
    end

    -- remove or reduce from expandedStock the items that were crafted during fulfillment of the targetStock.
    -- [example]: craft 2x redstone torch, have in storage: 2x redstone, 1x stick, 2x planks.
    -- because 1x more stick is needed, 4x sticks need to be crafted from the planks. since we now have plenty
    -- of sticks, we don't need to pull any from the storage.
    for item, quantity in pairs(craftedLeftoverStock) do
        if expandedStock[item] then
            local available = math.min(quantity, expandedStock[item])
            expandedStock[item] = expandedStock[item] - available
            craftedLeftoverStock[item] = craftedLeftoverStock[item] - available

            if expandedStock[item] <= 0 then
                expandedStock[item] = nil
            end

            if craftedLeftoverStock[item] <= 0 then
                craftedLeftoverStock[item] = nil
            end
        end
    end

    ---@type CraftingDetails
    local craftingDetails = {
        available = expandedStock,
        leftOver = craftedLeftoverStock,
        unavailable = unavailableStock,
        usedRecipes = Utils.reverse(usedRecipes)
    }

    return craftingDetails
end

---@param usedRecipes UsedCraftingRecipe[]
---@param maxSlotCount integer
---@param itemDetails ItemDetails
---@return UsedCraftingRecipe[]
function CraftingApi.chunkUsedRecipes(usedRecipes, maxSlotCount, itemDetails)
    ---@type UsedCraftingRecipe[]
    local chunked = {}

    for _, usedRecipe in pairs(usedRecipes) do
        if not itemDetails[usedRecipe.item] then
            error(string.format("ItemDetail for crafted item %s is missing", usedRecipe.item))
        end

        -- how often we can craft given the slot restriction
        local craftedBoundary = math.floor((maxSlotCount * itemDetails[usedRecipe.item].maxCount) / usedRecipe.quantity)

        if craftedBoundary == 0 then
            error(string.format("%dx slots are not enough to store even 1x craft of %s", maxSlotCount, usedRecipe.item))
        end

        -- how often we can craft given the max count restriction of an ingredient
        local ingredientBoundary = math.huge
        local ingredientSlotCount = 0

        for ingredient, ingredientSlots in pairs(usedRecipe.ingredients) do
            if not itemDetails[ingredient] then
                error(string.format("ItemDetail for ingredient %s is missing", ingredient))
            end

            ingredientSlotCount = ingredientSlotCount + #ingredientSlots

            if ingredientSlotCount > maxSlotCount then
                error(string.format("%dx slots are not enough to craft %s", maxSlotCount, usedRecipe.item))
            end

            ingredientBoundary = math.min(itemDetails[ingredient].maxCount, ingredientBoundary)
        end

        local boundary = math.min(craftedBoundary, ingredientBoundary)
        local open = usedRecipe.timesUsed

        while open > 0 do
            local chunkedUsedRecipe = Utils.clone(usedRecipe)
            chunkedUsedRecipe.timesUsed = math.min(boundary, open)
            table.insert(chunked, chunkedUsedRecipe)
            open = open - boundary
        end
    end

    return chunked
end

return CraftingApi
