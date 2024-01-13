package.path = package.path .. ";/lib/?.lua"

local Squirtle = require "squirtle"
local Inventory = require "inventory.inventory"
local CraftingInventory = require "inventory.crafting-inventory"

---@param chest string 
local function isInControl(chest)
    local slot = Inventory.findNameTag(chest, {"Crafter"}, Inventory.getStacks(chest))

    return slot == CraftingInventory.nameTagTurtleControlSlot
end

---@param chest string
local function recipeHasItems(chest)
    local inventory = Inventory.readCrafterInventory(chest)

    for _, stack in pairs(inventory.input.stacks) do
        if stack and stack.count > 0 then
            return true
        end
    end

    return false
end

---@param barrel string
local function barrelIsEmpty(barrel)
    return Inventory.isEmpty(Inventory.create(barrel))
end

---@param chest string
local function suckRecipe(chest)
    local inventory = Inventory.readCrafterInventory(chest)

    for turtleSlot, inventorySlot in pairs(inventory.input.slots) do
        local stack = inventory.input.stacks[inventorySlot]

        turtleSlot = turtleSlot + math.ceil(turtleSlot / 3) - 1

        if stack then
            Squirtle.select(turtleSlot)
            Squirtle.suckSlot(chest, inventorySlot, stack.count)
        end
    end

end

local function main()
    print("[io-network-crafter v1.0.0] booting...")
    local workbench = peripheral.find("workbench")

    if not workbench then
        error("no crafting table equipped :(")
    end

    while true do
        local chest = Inventory.findChest()

        if chest == "front" then
            if isInControl(chest) then
                print("[state] in control!")

                if recipeHasItems(chest) then
                    print("[state] recipe has items! sucking...")
                    suckRecipe(chest)
                elseif Squirtle.isEmpty() then
                    print("[state] giving back control")
                    Inventory.move(chest, CraftingInventory.nameTagTurtleControlSlot, CraftingInventory.nameTagIoNetworkControlSlot)
                else
                    print("[state] ready to craft! turning left...")
                    Squirtle.turn("left")
                end
            else
                os.sleep(3)
            end
        elseif chest == "right" then
            if Squirtle.isEmpty() then
                Squirtle.turn("right")
            else
                workbench.craft()
                Squirtle.turn("left")
            end
        elseif chest == "back" then
            while not (Squirtle.isEmpty() and barrelIsEmpty("bottom")) do
                print("dumping...")
                Squirtle.dump("bottom")
                Squirtle.dumpOutput("bottom", Inventory.readCrafterInventory("back"))
                os.sleep(3)
            end

            Squirtle.turn("right")
        end
    end
end

return main()

