if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local PeripheralApi = require "lib.common.peripheral-api"
local Shell = require "lib.system.shell"
local TurtleService = require "lib.turtle.turtle-service"
local EditEntity = require "lib.ui.edit-entity"

local function promptForWorkbench()
    term.clear()
    term.setCursorPos(1, 1)
    print("No workbench equipped, please put one into my equipment slots.\n")
    print("Make sure that the side the workbench is in is not also a side where the chest to take items from is.\n")
    Utils.waitForUserToHitEnter("<hit enter to retry>")
end

local function printBarrelUsage()
    term.clear()
    term.setCursorPos(1, 1)
    print("No barrel found, I need one next to me (either top, front or bottom) that contains the recipe.\n")
    print("Place the recipe into the rightmost slots of the barrel, just like you would in a crafting table.\n")
    Utils.waitForUserToHitEnter("<hit enter to retry>")
end

---@param side string
---@param name string
local function assertValidSide(side, name)
    if side ~= "top" and side ~= "front" and side ~= "bottom" then
        error(string.format("%s must be either at top, front or bottom", name))
    end
end

---@param name string
---@param chest string
---@return integer?
local function findItem(name, chest)
    local items = peripheral.call(chest, "list")

    for slot, item in pairs(items) do
        if item.name == name and item.count > 1 then
            return slot
        end
    end
end

---@param side string
local function dropSide(side)
    if side == "top" then
        turtle.dropUp()
    elseif side == "bottom" then
        turtle.dropDown()
    elseif side == "front" then
        turtle.drop()
    else
        error(string.format("invalid drop side: %s", side))
    end
end

---@param side string
---@param quantity integer?
local function suckSide(side, quantity)
    if side == "top" then
        turtle.suckUp(quantity)
    elseif side == "bottom" then
        turtle.suckDown(quantity)
    elseif side == "front" then
        turtle.suck(quantity)
    else
        error(string.format("invalid suck side: %s", side))
    end
end

---@param barrel string
---@param source string
local function loadRecipe(barrel, source)
    for i = 1, 9 do
        local recipeSlot = i + (6 * math.ceil(i / 3))
        ---@type ItemStack
        local recipeItem = peripheral.call(barrel, "getItemDetail", recipeSlot)

        if recipeItem then
            local inventorySlot = i + math.ceil(i / 3) - 1
            ---@type ItemStack
            local inventoryItem = turtle.getItemDetail(inventorySlot)

            if not inventoryItem then
                ---@type ItemStack
                local suckItem = peripheral.call(barrel, "getItemDetail", 1)

                if not suckItem then
                    local slot = findItem(recipeItem.name, source)

                    while not slot do
                        os.sleep(3)
                        slot = findItem(recipeItem.name, source)
                    end

                    peripheral.call(source, "pushItems", barrel, slot, 1, 1)
                end

                turtle.select(inventorySlot)
                suckSide(barrel, 1)
            end
        end
    end
end

---@param barrel string
---@return table<string, true>
function getRecipeItems(barrel)
    ---@type table<string, true>
    local items = {}

    for i = 1, 9 do
        local recipeSlot = i + (6 * math.ceil(i / 3))
        local stack = peripheral.call(barrel, "getItemDetail", recipeSlot)

        if stack then
            items[stack.name] = true
        end
    end

    return items
end

---@param source string
---@param target string
---@param barrel string
local function moveNonRecipeItems(source, target, barrel)
    while true do
        local recipeItems = getRecipeItems(barrel)
        ---@type table<integer, ItemStack>
        local sourceItems = peripheral.call(source, "list")

        for slot, sourceItem in pairs(sourceItems) do
            if not recipeItems[sourceItem.name] and sourceItem.name ~= "minecraft:name_tag" then
                peripheral.call(source, "pushItems", target, slot)
            end
        end

        os.sleep(7)
    end
end

local app = Shell.getApplication(arg)

app:addWindow("Main", function()
    -- [todo] ❌ need a way to know if app has been launched via the shell ui (or from terminal) or via autorun.
    -- if autorun and valid arguments exist, use those and skip showing EditEntity screen.
    local editEntity = EditEntity.new("Options", ".kita/data/crafter.options.json")
    editEntity:addString("source", "Source", {values = {"top", "front", "bottom"}})
    editEntity:addString("target", "Target", {values = {"top", "front", "bottom"}})
    editEntity:addString("trash", "Trash", {values = {"top", "front", "bottom", "back"}, optional = true})

    ---@class CrafterAppArguments
    ---@field source string
    ---@field target string
    ---@field trash string?
    ---@field returnHome boolean
    local arguments = editEntity:run({source = "top", target = "front"})

    if not arguments then
        return
    end

    local source = arguments.source
    local target = arguments.target
    local trash = arguments.trash

    local barrel = PeripheralApi.findSide("minecraft:barrel")

    while not barrel do
        printBarrelUsage()
        barrel = PeripheralApi.findSide("minecraft:barrel")
    end

    local workbench = peripheral.find("workbench")

    while not peripheral.find("workbench") do
        promptForWorkbench()
        workbench = peripheral.find("workbench")
    end

    term.clear()
    term.setCursorPos(1, 1)

    assertValidSide(barrel, "barrel")
    assertValidSide(target, "target")

    if source == barrel or target == barrel or trash == barrel then
        error("barrel can not be the source, target or trash")
    end

    print("[ok] ready for crafting!")
    local craftTargetSlot = 16

    EventLoop.run(function()
        while true do
            if turtle.getItemCount(craftTargetSlot) > 0 then
                dropSide(target)
            else
                loadRecipe(barrel, source)
                turtle.select(craftTargetSlot)
                workbench.craft()
            end
        end
    end, function()
        moveNonRecipeItems(source, trash or target, barrel)
    end)

end)

app:addWindow("RPC", function()
    Rpc.host(TurtleService, "wireless")
end)

app:run()
