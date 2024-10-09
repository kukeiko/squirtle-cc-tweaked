package.path = package.path .. ";/?.lua"

local EventLoop = require "lib.common.event-loop"
local Peripheral = require "lib.common.peripheral"

local function printUsage()
    print("Usage: crafter <source> <target> [trash]")
    print("- target must be one of: top, bottom, front")
    print("- needs a barrel at either: top, bottom, front")
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

-- [todo] why not just use peripheral.find("workbench")?
local function wrapCraftingTable()
    local left = peripheral.getType("left")

    if left == "workbench" then
        return peripheral.wrap("left")
    end

    local right = peripheral.getType("right")

    if right == "workbench" then
        return peripheral.wrap("right")
    end

    error("no workbench equipped :(")
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
local function moveNonRecipeItemsFromSourceToTarget(source, target, barrel)
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

---@param args string[]
local function main(args)
    print("[crafter v2.3.0-dev] booting...")
    local workbench = wrapCraftingTable()
    local source = args[1]
    local target = args[2]
    local trash = args[3]

    if not source or not target then
        return printUsage()
    end

    local barrel = Peripheral.findSide("minecraft:barrel")

    if not barrel then
        error("no barrel found :(")
    end

    assertValidSide(barrel, "barrel")
    assertValidSide(target, "target")

    if source == barrel or target == barrel or trash == barrel then
        error("barrel can not be the source, target or trash")
    end

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
        moveNonRecipeItemsFromSourceToTarget(source, trash or target, barrel)
    end)

end

return main(arg)
