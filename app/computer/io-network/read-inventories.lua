local getStacks = require "world.chest.get-stacks"
local printProgress = require "io-network.print-progress"
local findNameTag = require "io-network.find-name-tag"
local readInputOutputChest = require "io-network.read-io-chest"
local readStorageChest = require "io-network.read-storage-chest"
local readOutputDumpChest = require "io-network.read-output-dump-chest"
local readAssignedChest = require "io-network.read-assigned-chest"
local readFurnace = require "io-network.read-furnace"

---@param found FoundInventory[]
---@param barrel string
return function(found, barrel)
    -- [todo] thinking of removing the feature of programming dumps/assigned chests,
    -- as it is a bit cumbersome (renaming based on name assigned from moden) and not really needed:
    -- 1) dumps can now be programmed via putting a "Drain" name-tag in them
    -- 2) assigned chests of 1x item type can be achieved using redstone
    local barrelStacks = getStacks(barrel, true)
    ---@type table<string, ItemStack[]>
    local assigned = {}
    ---@type table<string, string>
    local dumps = {}

    for _, barrelStack in pairs(barrelStacks) do
        if barrelStack.name == "minecraft:chest" then
            dumps[barrelStack.displayName] = barrelStack.name
        else
            if not assigned[barrelStack.displayName] then
                assigned[barrelStack.displayName] = {}
            end

            table.insert(assigned[barrelStack.displayName], barrelStack)
        end
    end

    local inventories = {}
    print("reading", #found, "inventories...")
    local x, y = printProgress(0, #found)

    for i, foundInventory in ipairs(found) do
        local name = foundInventory.name

        if dumps[name] then
            table.insert(inventories, readOutputDumpChest(name))
        elseif assigned[name] then
            -- if chest name is found in barrel, it is an assigned one, and I/O nametags are ignored.
            table.insert(inventories, readAssignedChest(name, assigned[name]))
        elseif foundInventory.type == "minecraft:furnace" then
            table.insert(inventories, readFurnace(name))
        else
            local stacks = getStacks(name)
            local nameTagSlot, nameTagName = findNameTag(name, {"I/O", "Drain"}, stacks)

            if nameTagSlot and nameTagName then
                if nameTagName == "I/O" then
                    table.insert(inventories, readInputOutputChest(name, stacks, nameTagSlot))
                elseif nameTagName == "Drain" then
                    table.insert(inventories, readOutputDumpChest(name, {nameTagSlot}))
                end
            else
                table.insert(inventories, readStorageChest(name, stacks))
            end
        end

        x, y = printProgress(i, #found, x, y)
    end

    return inventories
end
