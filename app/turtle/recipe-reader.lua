if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local RemoteService = require "lib.systems.runtime.remote-service"
local DatabaseService = require "lib.systems.database.database-service"
local TurtleApi = require "lib.apis.turtle.turtle-api"

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

EventLoop.run(function()
    RemoteService.run({"recipe-reader"})
end, function()

    while true do
        readRecipe()
    end
end)

