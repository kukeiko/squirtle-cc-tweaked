---@class BoneMealAppState
local state = {
    blocks = {
        chest = "minecraft:chest",
        hopper = "minecraft:hopper",
        dropper = "minecraft:dropper",
        dispenser = "minecraft:dispenser",
        furnace = "minecraft:furnace",
        observer = "minecraft:observer",
        comparator = "minecraft:comparator",
        composter = "minecraft:composter",
        repeater = "minecraft:repeater",
        redstone = "minecraft:redstone",
        redstoneBlock = "minecraft:redstone_block",
        redstoneTorch = "minecraft:redstone_torch",
        stickyPiston = "minecraft:sticky_piston",
        filler = "minecraft:smooth_stone",
        stone = "minecraft:stone",
        trapdoor = "minecraft:spruce_trapdoor",
        piston = "minecraft:piston",
        lever = "minecraft:lever",
        bucket = "minecraft:bucket",
        waterBucket = "minecraft:water_bucket",
        lavaBucket = "minecraft:lava_bucket",
        boneMeal = "minecraft:bone_meal",
        moss = "minecraft:moss_block"
    }
}

local function printUsage()
    print("Usage:")
    print("bone-meal ???")
    print("---")
    print("Example:")
    print("???")
end

---@param args table<string>
---@return BoneMealAppState?
return function(args)

    return state
end
