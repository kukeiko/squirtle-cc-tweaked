if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local RemoteService = require "lib.systems.runtime.remote-service"
local DatabaseService = require "lib.systems.database.database-service"
local StorageService = require "lib.systems.storage.storage-service"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local Shell = require "lib.ui.shell"
local SearchableList = require "lib.ui.searchable-list"

print(string.format("[recipe-reader %s] booting...", version()))
Utils.writeStartupFile("recipe-reader")

local function readRecipe()
    local workbench = peripheral.find("workbench")
    local databaseService = Rpc.nearest(DatabaseService)
    local bannedSlots = {4, 8, 12, 13, 14, 15, 16}

    if not workbench then
        error("no crafting table equipped :(")
    end

    term.clear()
    term.setCursorPos(1, 1)
    print("To add a new crafting recipe, place the ingredients into my inventory just like you would do in a crafting table.\n")
    print("You can not use the last column or the last row to place the ingredients.\n")
    print("Once you're done, hit enter.\n")
    Utils.waitForUserToHitEnter()
    local ingredients = TurtleApi.getStacks()

    for slot in pairs(ingredients) do
        if Utils.indexOf(bannedSlots, slot) then
            print(string.format("You used a bad slot: %d", slot))
            return os.sleep(3)
        end
    end

    if Utils.isEmpty(ingredients) then
        print("You didn't put any ingredients.")
        return os.sleep(1)
    end

    local success, message = workbench.craft()

    if not success then
        print(message)
        return os.sleep(3)
    end

    local crafted = TurtleApi.getStock()
    local item = next(crafted)

    if not item then
        print("Didn't find a crafted item, weird.")
        return os.sleep(1)
    else
        ---@type CraftingRecipe
        local recipe = {item = item, quantity = crafted[item], ingredients = {}}

        for slot, stack in pairs(ingredients) do
            local recipeSlot = slot - (math.ceil(slot / 4) - 1)

            if not recipe.ingredients[stack.name] then
                recipe.ingredients[stack.name] = {}
            end

            table.insert(recipe.ingredients[stack.name], recipeSlot)
        end

        databaseService.saveCraftingRecipe(recipe)
        term.clear()
        term.setCursorPos(1, 1)
        print(string.format("Added recipe for %s!\n", item))
        print("Please take out the crafted items")

        while not TurtleApi.isEmpty() do
            EventLoop.pull("turtle_inventory")
        end
    end
end

---@param recipe CraftingRecipe
local function showRecipeDetails(recipe)
    print(string.format("Ingredients for %s:", recipe.item))

    for ingredient, slots in pairs(recipe.ingredients) do
        print(string.format(" - %dx %s", #slots, ingredient))
    end

    print("\n")
    Utils.waitForUserToHitEnter("<hit enter to go back>")
end

local function browse()
    local storageService = Rpc.nearest(StorageService)
    local recipes = storageService.getCraftingRecipes()

    ---@return SearchableListOption[]
    local function getListOptions()
        recipes = storageService.getCraftingRecipes()
        local itemDetails = storageService.getItemDetails()

        local options = Utils.map(recipes, function(recipe, item)
            ---@type SearchableListOption
            return {id = item, name = itemDetails[item].displayName}
        end)

        table.sort(options, function(a, b)
            return a.name < b.name
        end)

        return options
    end

    local searchableList = SearchableList.new(getListOptions(), "Recipes", 10, 3, getListOptions)

    while true do
        local selected = searchableList:run()

        if selected and recipes[selected.id] then
            showRecipeDetails(recipes[selected.id])
        end
    end
end

Shell:addWindow("Add Recipe", function()
    while true do
        readRecipe()
    end
end)

Shell:addWindow("Browse Recipes", function()
    browse()
end)

Shell:addWindow("RPC", function()
    RemoteService.run({"recipe-reader"})
end)

Shell:run()
