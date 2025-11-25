local Utils = require "lib.tools.utils"
local EntityRepository = require "lib.database.entity-repository"

---@class CraftingRecipeRepository
local CraftingRecipeRepository = {}
local repository = EntityRepository.new("crafting-recipes", false, "item")

---@return CraftingRecipes
function CraftingRecipeRepository.getAll()
    ---@type CraftingRecipe[]
    local recipes = repository:getAll()

    return Utils.toMap(recipes, function(item)
        return item.item
    end)
end

---@param item string
---@return CraftingRecipe?
function CraftingRecipeRepository.find(item)
    return repository:find(item)
end

---@param recipe CraftingRecipe
function CraftingRecipeRepository.save(recipe)
    repository:save(recipe)
end

return CraftingRecipeRepository
