---@class ItemApi
local ItemApi = {
    boneMeal = "minecraft:bone_meal",
    barrel = "minecraft:barrel",
    chest = "minecraft:chest",
    shulkerBox = "minecraft:shulker_box",
    diskDrive = "computercraft:disk_drive",
    bucket = "minecraft:bucket",
    lavaBucket = "minecraft:lava_bucket",
    coal = "minecraft:coal",
    charcoal = "minecraft:charcoal",
    coalBlock = "minecraft:coal_block",
    crimsonNylium = "minecraft:crimson_nylium",
    warpedNylium = "minecraft:warped_nylium",
    crimsonFungus = "minecraft:crimson_fungus",
    warpedFungus = "minecraft:warped_fungus",
    crimsongStem = "minecraft:crimson_stem",
    warpedStem = "minecraft:warped_stem",
    netherWartBlock = "minecraft:nether_wart_block",
    warpedWartblock = "minecraft:warped_wart_block",
    weepingVines = "minecraft:weeping_vines",
    weepingVinesPlant = "minecraft:weeping_vines_plant",
    twistingVines = "minecraft:twisting_vines",
    twistingVinesPlant = "minecraft:twisting_vines_plant",
    shroomlight = "minecraft:shroomlight"
}

---@param variant "crimson" | "warped"
function ItemApi.getNylium(variant)
    if variant == "crimson" then
        return ItemApi.crimsonNylium
    elseif variant == "warped" then
        return ItemApi.warpedNylium
    else
        error(string.format("unknown nylium variant %s", variant))
    end
end

---@param variant "crimson" | "warped"
function ItemApi.getFungus(variant)
    if variant == "crimson" then
        return ItemApi.crimsonFungus
    elseif variant == "warped" then
        return ItemApi.warpedFungus
    else
        error(string.format("unknown fungus variant %s", variant))
    end
end

---@param variant "crimson" | "warped"
function ItemApi.getStem(variant)
    if variant == "crimson" then
        return ItemApi.crimsongStem
    elseif variant == "warped" then
        return ItemApi.warpedStem
    else
        error(string.format("unknown stem variant %s", variant))
    end
end

---@param variant "crimson" | "warped"
function ItemApi.getWartBlock(variant)
    if variant == "crimson" then
        return ItemApi.netherWartBlock
    elseif variant == "warped" then
        return ItemApi.warpedWartblock
    else
        error(string.format("unknown wart block variant %s", variant))
    end
end

---@param variant "crimson" | "warped"
function ItemApi.getVines(variant)
    if variant == "crimson" then
        return ItemApi.weepingVines
    elseif variant == "warped" then
        return ItemApi.twistingVines
    else
        error(string.format("unknown vines variant %s", variant))
    end
end

---@param variant "crimson" | "warped"
function ItemApi.getVinesPlant(variant)
    if variant == "crimson" then
        return ItemApi.weepingVinesPlant
    elseif variant == "warped" then
        return ItemApi.twistingVinesPlant
    else
        error(string.format("unknown vines plant variant %s", variant))
    end
end

return ItemApi
