local Utils = require "lib.common.utils"

---@class CraftingRecipe
---@field item string The item that is crafted.
---@field quantity integer How many of the item will be crafted.
---@field ingredients table<string, integer[]> The ingredients required to craft the item.
---
---@alias CraftingRecipes table<string, CraftingRecipe>
---

---@param recipe CraftingRecipe
---@param recipes CraftingRecipes
---@return string[]
local function getIngredients(recipe, recipes)
    ---@type table<string, string>
    local ingredients = {}

    ---@param recipe CraftingRecipe
    local function recurse(recipe)
        for ingredient in pairs(recipe.ingredients) do
            if not ingredients[ingredient] then
                ingredients[ingredient] = ingredient

                if recipes[ingredient] then
                    recurse(recipes[ingredient])
                end
            end
        end
    end

    recurse(recipe)

    return Utils.toList(ingredients)
end

return {getIngredients = getIngredients}
