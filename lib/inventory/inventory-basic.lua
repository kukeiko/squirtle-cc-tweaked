local Utils = require "utils"
local findSide = require "world.peripheral.find-side"
local InventoryElemental = require "inventory.inventory-elemental"

---@type table<string, integer>
local itemMaxCounts = {}

-- [todo] already copied in several files, and adapted here to set maxCounts (instead of refuel amount)
local fuelItems = {["minecraft:lava_bucket"] = 1, ["minecraft:coal"] = 64, ["minecraft:charcoal"] = 64, ["minecraft:coal_block"] = 64}
local smeltableItems = {["minecraft:cobblestone"] = "minecraft:stone", ["minecraft:stone"] = "minecraft:smooth_stone"}

---@class InventoryBasic : InventoryElemental
local InventoryBasic = {}
setmetatable(InventoryBasic, {__index = InventoryElemental})

---@param inventory string
---@param fromSlot integer
---@param toSlot? integer
---@param quantity? integer
---@return integer
function InventoryBasic.move(inventory, fromSlot, toSlot, quantity)
    os.sleep(.5) -- [note] exists on purpose, as I don't want turtles to move items too quickly in suckSlot()
    return InventoryElemental.pushItems(inventory, inventory, fromSlot, quantity, toSlot)
end

---@return string
function InventoryBasic.findChest()
    local chest = findSide("minecraft:chest")

    if chest then
        return chest
    end

    error("no chest found")
end

---@param item string
---@param chest string
---@param slot integer
function InventoryBasic.getItemMaxCount(item, chest, slot)
    if not itemMaxCounts[item] then
        ---@type ItemStack|nil
        local detailedStack = InventoryElemental.getStack(chest, slot)

        if detailedStack then
            itemMaxCounts[item] = detailedStack.maxCount
        end
    end

    return itemMaxCounts[item]
end

---@param name string
---@param detailed? boolean
---@return ItemStacks
function InventoryBasic.getStacks(name, detailed)
    if not detailed then
        ---@type ItemStacks
        local stacks = peripheral.call(name, "list")

        for slot, stack in pairs(stacks) do
            stack.maxCount = InventoryBasic.getItemMaxCount(stack.name, name, slot)
        end

        return stacks
    else
        local stacks = peripheral.call(name, "list")
        ---@type ItemStacks
        local detailedStacks = {}

        for slot, _ in pairs(stacks) do
            detailedStacks[slot] = peripheral.call(name, "getItemDetail", slot)
        end

        return detailedStacks
    end
end

---@param inventory Inventory
---@param item string
---@return boolean
function InventoryBasic.canProvideItem(inventory, item)
    return inventory.stock[item] and inventory.stock[item].count > 0
end

---@param inventories Inventory[]
---@param item string
---@return Inventory[]
function InventoryBasic.filterCanProvideItem(inventories, item)
    return Utils.filter(inventories, function(candidate)
        return InventoryBasic.canProvideItem(candidate, item)
    end)
end

---@param inventory Inventory
---@param item string
---@return boolean
function InventoryBasic.hasSpaceForItem(inventory, item)
    return InventoryBasic.getSpaceForItem(inventory, item) > 0
end

---@param inventories Inventory[]
---@param item string
---@return Inventory[]
function InventoryBasic.filterHasSpaceForItem(inventories, item)
    return Utils.filter(inventories, function(candidate)
        return InventoryBasic.hasSpaceForItem(candidate, item)
    end)
end

---@param inventory Inventory
---@param item string
---@return integer
function InventoryBasic.getSpaceForItem(inventory, item)
    local stock = inventory.stock[item]

    if stock then
        return stock.maxCount - stock.count
    elseif not stock and InventoryBasic.isFurnace(inventory) then
        if fuelItems[item] and not InventoryElemental.getFurnaceFuelStack(inventory) then
            return fuelItems[item]
        elseif smeltableItems[item] and not InventoryElemental.getFurnaceInputStack(inventory) then
            -- [todo] hmmm
            return 64
        end
    end

    return 0
end

---@param inventory Inventory
---@return string
function InventoryBasic.getBlockType(inventory)
    local blockType = peripheral.getType(inventory.name)

    if not blockType then
        error(string.format("%s does not have a type", inventory.name))
    end

    return blockType
end

---@param inventory Inventory
---@return boolean
function InventoryBasic.isFurnace(inventory)
    return InventoryBasic.getBlockType(inventory) == "minecraft:furnace"
end

---@param name string
---@param tagNames table<string>
---@param stacks table<integer, ItemStack>
---@return integer? slot, string? name
function InventoryBasic.findNameTag(name, tagNames, stacks)
    for slot, stack in pairs(stacks) do
        if stack.name == "minecraft:name_tag" then
            local stack = InventoryElemental.getStack(name, slot)

            if Utils.indexOf(tagNames, stack.displayName) > 0 then
                return slot, stack.displayName
            end
        end
    end
end

return InventoryBasic
