local getStacks = require "world.chest.get-stacks"
local findNameTag = require "io-network.find-name-tag"
local readInputOutputChest = require "io-network.read-io-chest"
local readStorageChest = require "io-network.read-storage-chest"
local readOutputDumpChest = require "io-network.read-output-dump-chest"
local readAssignedChest = require "io-network.read-assigned-chest"

---@param chests string[]
---@param barrel string
return function(chests, barrel)
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

    local networkedChests = {}

    print("reading", #chests, "networked chests...")

    for i, chest in ipairs(chests) do
        if i == math.ceil(#chests * .25) then
            print("25%")
        elseif i == math.ceil(#chests * .5) then
            print("50%")
        elseif i == math.ceil(#chests * .75) then
            print("75%")
        end

        if dumps[chest] then
            table.insert(networkedChests, readOutputDumpChest(chest))
        elseif assigned[chest] then
            -- if chest name is found in barrel, it is an assigned one, and I/O nametags are ignored.
            table.insert(networkedChests, readAssignedChest(chest, assigned[chest]))
        else
            local stacks = getStacks(chest)
            local nameTagSlot, nameTagName = findNameTag(chest, {"I/O", "Drain"}, stacks)

            if nameTagSlot and nameTagName then
                if nameTagName == "I/O" then
                    table.insert(networkedChests, readInputOutputChest(chest, stacks, nameTagSlot))
                elseif nameTagName == "Drain" then
                    table.insert(networkedChests, readOutputDumpChest(chest, {nameTagSlot}))
                end
            else
                table.insert(networkedChests, readStorageChest(chest, stacks))
            end
        end
    end

    print("100%")

    return networkedChests
end
