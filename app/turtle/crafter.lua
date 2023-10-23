package.path = package.path .. ";/lib/?.lua"

local findSide = require "world.peripheral.find-side"
local SquirtleV2 = require "squirtle.squirtle-v2"

---@param name string
---@param chest string
---@return integer?
local function findItem(name, chest)
    local items = peripheral.call(chest, "list")

    for slot, item in pairs(items) do
        if item.name == name then
            return slot
        end
    end
end

local function assertHasCraftingTable()
    local left = peripheral.getType("left")

    if left == "workbench" then
        return
    end

    local right = peripheral.getType("right")

    if right == "workbench" then
        return
    end

    error("no workbench equipped :(")
end

local function main(args)
    print("[crafter v1.0.0] booting...")
    assertHasCraftingTable()
    local barrel = findSide("minecraft:barrel")

    if not barrel then
        error("no barrel found :(")
    end

    local sourceChest = "top"
    local offset = 6

    while true do
        for i = 1, 9 do
            local recipeSlot = i + (offset * math.ceil(i / 3))
            local recipeItem = peripheral.call(barrel, "getItemDetail", recipeSlot)

            if recipeItem then
                local targetSlot = recipeSlot - 3
                local targetItem = peripheral.call(barrel, "getItemDetail", targetSlot)
                local invItem = turtle.getItemDetail(i + math.ceil(i / 3) - 1)

                if not targetItem and not invItem then
                    while true do
                        local slot = findItem(recipeItem.name, sourceChest)

                        if slot then
                            peripheral.call(sourceChest, "pushItems", barrel, slot, 1, targetSlot)
                            break
                        end

                        os.sleep(7)
                    end
                end
            end
        end

        for i = 1, 9 do
            if not turtle.getItemDetail(i + math.ceil(i / 3) - 1) then
                local fromSlot = (i + (offset * math.ceil(i / 3))) - 3
                peripheral.call(barrel, "pushItems", barrel, fromSlot, 1, 1)
                turtle.select(i + math.ceil(i / 3) - 1)
                turtle.suckDown(1)
            end
        end

        turtle.craft()
        SquirtleV2.dump("front")
    end

end

return main(arg)
