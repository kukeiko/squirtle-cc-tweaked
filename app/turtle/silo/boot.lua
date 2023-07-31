-- required blocks (for layers = 4)
-- (64 + 33)x smooth_stone
-- 37x oak_loag
-- 29x stripped_oak_log
-- 10x redstone_lamp
-- 19x chests
-- 10x hopper
-- 10x comparator
-- 22x repeater
-- 13x redstone
-- 1x redstone_torch


---@class SiloAppState
local state = {
    ---@type "left" | "right"
    lampLocation = "left",
    ---@type "light" | "dark" | "basalt"
    theme = "light",
    layers = 4,
    blocks = {
        chest = "minecraft:chest",
        hopper = "minecraft:hopper",
        lamp = "minecraft:redstone_lamp",
        comparator = "minecraft:comparator",
        repeater = "minecraft:repeater",
        redstone = "minecraft:redstone",
        redstoneTorch = "minecraft:redstone_torch",
        -- variadic blocks
        filler = "minecraft:smooth_stone",
        backside = "minecraft:stripped_oak_log",
        support = "minecraft:oak_log"
    }
}

local function printUsage()
    print("Usage:")
    print("silo <side> <layers> [theme]")
    print("---")
    print("Example:")
    print("silo left 4 dark")
    print("silo right 1")
    print("available themes: light, dark, basalt")
end

---@param args table<string>
---@return SiloAppState?
return function(args)
    if not args[1] or not args[2] then
        printUsage()
        return nil
    end

    if string.lower(args[1]) == "right" then
        state.lampLocation = "right"
    elseif string.lower(args[1]) == "left" then
        state.lampLocation = "left"
    else
        printUsage()
        return nil
    end

    local layers = tonumber(args[2])

    if not layers then
        printUsage()
        return nil
    end

    state.layers = layers

    if not args[3] then
        state.theme = "light"
    elseif string.lower(args[3]) == "dark" then
        state.theme = "dark"
    elseif string.lower(args[3]) == "basalt" then
        state.theme = "basalt"
    end

    if state.theme == "basalt" then
        state.blocks.backside = "minecraft:deepslate_tiles"
        state.blocks.support = "minecraft:polished_basalt"
    elseif state.theme == "dark" then
        state.blocks.support = "minecraft:dark_oak_log"
    end

    return state
end
