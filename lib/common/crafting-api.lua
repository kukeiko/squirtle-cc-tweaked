local Utils = require "lib.common.utils"

---@class CraftingApi
local CraftingApi = {}

---Given an item, returns the maximum number of times it could be crafted based on what is available in storedStock,
---ignoring that ingredients might be used by multiple items within the recipe tree of the item (hence "optimistic").
---Used to determine the upper bound for the binary search in getCraftableCount() as an optimization step.
---@param item string
---@param storedStock ItemStock
---@param recipesMap table<string, CraftingRecipe>
---@param blacklist? string[]
---@return integer
local function getOptimisticCraftableCount(item, storedStock, recipesMap, blacklist)
    blacklist = Utils.copy(blacklist or {})
    table.insert(blacklist, item)
    local recipe = recipesMap[item]
    local stored = storedStock[item] or 0

    if not recipe then
        return stored
    end

    ---@type integer?
    local lowest

    for ingredient, ingredientSlots in pairs(recipe.ingredients) do
        if not Utils.indexOf(blacklist, ingredient) then
            local crafted = math.floor(getOptimisticCraftableCount(ingredient, storedStock, recipesMap, blacklist) / #ingredientSlots)
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
---@param recipesMap table<string, CraftingRecipe>
---@param blacklist? string[]
---@return integer
function CraftingApi.getCraftableCount(item, storedStock, recipesMap, blacklist)
    local low, high = 0, getOptimisticCraftableCount(item, storedStock, recipesMap, blacklist)
    high = high - (storedStock[item] or 0)

    while low < high do
        local mid = math.floor((low + high + 1) / 2)
        local craftingDetails = CraftingApi.getCraftingDetails({[item] = mid}, storedStock, recipesMap)

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
---@param targetStock ItemStock
---@param currentStock ItemStock
---@param recipes table<string, CraftingRecipe>
---@return CraftingDetails
function CraftingApi.getCraftingDetails(targetStock, currentStock, recipes)
    ---@type ItemStock
    local expandedStock = {}
    ---@type ItemStock
    local unavailableStock = {}
    ---@type ItemStock
    local craftedLeftoverStock = {}
    ---@type UsedCraftingRecipe[]
    local usedRecipes = {}
    currentStock = Utils.clone(currentStock)

    for item, quantity in pairs(targetStock) do
        if currentStock[item] then
            currentStock[item] = math.max(0, currentStock[item] - quantity)
        end
    end

    ---@param item string
    ---@param openQuantity integer
    ---@param blacklist? string[]
    local function recurse(item, openQuantity, blacklist)
        blacklist = Utils.copy(blacklist or {})
        table.insert(blacklist, item)

        if craftedLeftoverStock[item] then
            local availableLeftOver = craftedLeftoverStock[item]
            craftedLeftoverStock[item] = math.max(0, availableLeftOver - openQuantity)
            openQuantity = math.max(0, openQuantity - availableLeftOver)
        end

        local available = math.min(currentStock[item] or 0, openQuantity)

        if available > 0 then
            currentStock[item] = currentStock[item] - available
            expandedStock[item] = (expandedStock[item] or 0) + available
        end

        if available < openQuantity then
            local open = openQuantity - available
            local recipe = recipes[item]

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
                    timesUsed = timesCrafted
                }
                table.insert(usedRecipes, usedRecipe)

                if craftedQuantity > open then
                    craftedLeftoverStock[item] = (craftedLeftoverStock[item] or 0) + (craftedQuantity - open)
                end

                for ingredient, ingredientSlots in pairs(recipe.ingredients) do
                    recurse(ingredient, #ingredientSlots * timesCrafted, blacklist)
                end
            else
                unavailableStock[item] = (unavailableStock[item] or 0) + open
            end
        end
    end

    for item, quantity in pairs(targetStock) do
        recurse(item, quantity)
    end

    -- remove or reduce from expandedStock the items that were crafted during fulfillment of the targetStock.
    -- [example] craft 2x redstone torch, have: 2x redstone, 1x stick, 2x planks.
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

return CraftingApi
