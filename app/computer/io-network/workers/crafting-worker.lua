local Utils = require "utils"
local CraftingInventory = require "inventory.crafting-inventory"
local DatabaseService = require "services.database-service"
local transferStock = require "io-network.transfer-stock"

---@param recipe CraftingRecipe
---@param inventory Inventory
local function applyRecipe(recipe, inventory)
    for ingredient, slots in pairs(recipe.ingredients) do
        for _, slot in pairs(slots) do
            ---@type ItemStack
            local stack = {count = 0, name = ingredient, maxCount = 1}
            inventory.stacks[inventory.slots[slot]] = stack

            if not inventory.stock[ingredient] then
                local stock = Utils.clone(stack)
                stock.count = 0
                stock.maxCount = 0
                inventory.stock[ingredient] = stock
            end

            inventory.stock[ingredient].maxCount = inventory.stock[ingredient].maxCount + 1
        end
    end
end

---@param collection InventoryCollection
return function(collection)

    os.pullEvent("key")

    local craftingInventories = collection:getInventories("crafter")
    local firstCraftingInventory = craftingInventories[1]
    local recipe = DatabaseService.getCraftingRecipe("minecraft:glass_pane")

    if not recipe then
        error("recipe not found")
    end

    if firstCraftingInventory.tagSlot == CraftingInventory.nameTagIoNetworkControlSlot then
        print("loading recipe...")
        applyRecipe(recipe, firstCraftingInventory.input)
        ---@type ItemStock
        local stock = {}

        for _, stack in pairs(firstCraftingInventory.input.stock) do
            stock[stack.name] = Utils.clone(stack)
            stock[stack.name].count = stack.maxCount
        end

        transferStock(stock, collection:getInventories("storage"), {firstCraftingInventory}, collection)
    end
end
