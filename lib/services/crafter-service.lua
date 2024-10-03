local Utils = require "utils"
local InventoryPeripheral = require "inventory.inventory-peripheral"
local Squirtle = require "squirtle"

---@class CrafterService : Service
local CrafterService = {name = "crafter"}

---@param inventory string
---@param item string
---@return integer?
local function findItem(inventory, item)
    for slot, stack in pairs(InventoryPeripheral.getStacks(inventory)) do
        if stack.name == item then
            return slot
        end
    end
end

-- [todo] check that sufficient crafting materials are provided
---@param recipe CraftingRecipe
---@param quantity? integer
function CrafterService.craft(recipe, quantity)
    quantity = math.max(quantity or 1, recipe.count)
    local inventory = "bottom"
    local workbench = peripheral.find("workbench")

    if not workbench then
        error("no crafting table equipped :(")
    end

    for item, slots in pairs(recipe.ingredients) do
        for _, recipeSlot in pairs(slots) do
            local inventorySlot = findItem(inventory, item)

            if not inventorySlot then
                error(string.format("item %s missing in chest", item))
            end

            local turtleSlot = recipeSlot + math.ceil(recipeSlot / 3) - 1
            Squirtle.select(turtleSlot)
            Squirtle.suckSlot(inventory, inventorySlot, quantity / recipe.count)
        end
    end

    workbench.craft()
    Squirtle.dump(inventory)
end

---@param targetStock ItemStock
---@param currentStock ItemStock
---@param recipes table<string, CraftingRecipe>
---@return ItemStock expanded, ItemStock unavailable, ItemStock leftover, table<string, integer> recipes
function CrafterService.expandItemStock(targetStock, currentStock, recipes)
    ---@type ItemStock
    local expandedStock = {}
    ---@type ItemStock
    local unavailableStock = {}
    ---@type ItemStock
    local craftedLeftoverStock = {}
    ---@type table<string, integer>
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
                    local timesCrafted = math.ceil(open / recipe.count)
                    local craftedQuantity = timesCrafted * recipe.count
                    usedRecipes[item] = (usedRecipes[item] or 0) + timesCrafted

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

    return expandedStock, unavailableStock, craftedLeftoverStock, usedRecipes
end

return CrafterService
