local Utils = require "lib.common.utils"

---@class CrafterService : Service
local CrafterService = {name = "crafter"}

---[todo] "recipes" argument should instead just be CraftingRecipe[]
---[todo] throw error if targetStock contains items for which there are no recipes
---@param targetStock ItemStock
---@param currentStock ItemStock
---@param recipes table<string, CraftingRecipe>
---@return CraftingDetails
function CrafterService.getCraftingDetails(targetStock, currentStock, recipes)
    ---@type ItemStock
    local expandedStock = {}
    ---@type ItemStock
    local unavailableStock = {}
    ---@type ItemStock
    local craftedLeftoverStock = {}
    ---@type UsedCraftingRecipe[]
    local usedRecipes = {}
    local openStock = Utils.clone(targetStock)
    currentStock = Utils.clone(currentStock)

    while not Utils.isEmpty(openStock) do
        ---@type ItemStock
        local nextOpenStock = {}

        for item, quantity in pairs(openStock) do
            if craftedLeftoverStock[item] then
                quantity = math.max(0, quantity - craftedLeftoverStock[item])
                craftedLeftoverStock[item] = craftedLeftoverStock[item] - quantity
            end

            local available = math.min(currentStock[item] or 0, quantity)

            if available > 0 then
                currentStock[item] = currentStock[item] - available
                expandedStock[item] = (expandedStock[item] or 0) + available
            end

            if available < quantity then
                local open = quantity - available
                local recipe = recipes[item]

                if recipe then
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

                    for ingredient, ingredientSlots in pairs(recipe.ingredients) do
                        local ingredientQuantity = timesCrafted * #ingredientSlots
                        nextOpenStock[ingredient] = (nextOpenStock[ingredient] or 0) + ingredientQuantity

                        if craftedQuantity > open then
                            craftedLeftoverStock[item] = (craftedLeftoverStock[item] or 0) + (craftedQuantity - open)
                        end
                    end
                else
                    unavailableStock[item] = (unavailableStock[item] or 0) + open
                end
            end
        end

        openStock = nextOpenStock
    end

    -- remove or reduce from expandedStock the items that were crafted during fulfillment of the targetStock
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

return CrafterService
