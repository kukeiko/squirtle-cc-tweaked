---@class ItemApi
local ItemApi = {
    barrel = "minecraft:barrel",
    boneMeal = "minecraft:bone_meal",
    bucket = "minecraft:bucket",
    charcoal = "minecraft:charcoal",
    chest = "minecraft:chest",
    coal = "minecraft:coal",
    coalBlock = "minecraft:coal_block",
    comparator = "minecraft:comparator",
    composter = "minecraft:composter",
    computer = "computercraft:computer_normal",
    crimsonFungus = "minecraft:crimson_fungus",
    crimsongStem = "minecraft:crimson_stem",
    crimsonNylium = "minecraft:crimson_nylium",
    diskDrive = "computercraft:disk_drive",
    dispenser = "minecraft:dispenser",
    dropper = "minecraft:dropper",
    furnace = "minecraft:furnace",
    hopper = "minecraft:hopper",
    lavaBucket = "minecraft:lava_bucket",
    lever = "minecraft:lever",
    moss = "minecraft:moss_block",
    netherWartBlock = "minecraft:nether_wart_block",
    networkCable = "computercraft:cable",
    observer = "minecraft:observer",
    piston = "minecraft:piston",
    redstone = "minecraft:redstone",
    redstoneBlock = "minecraft:redstone_block",
    redstoneTorch = "minecraft:redstone_torch",
    repeater = "minecraft:repeater",
    shroomlight = "minecraft:shroomlight",
    shulkerBox = "minecraft:shulker_box",
    smoothStone = "minecraft:smooth_stone",
    stickyPiston = "minecraft:sticky_piston",
    stone = "minecraft:stone",
    trapdoor = "minecraft:spruce_trapdoor",
    twistingVines = "minecraft:twisting_vines",
    twistingVinesPlant = "minecraft:twisting_vines_plant",
    warpedFungus = "minecraft:warped_fungus",
    warpedNylium = "minecraft:warped_nylium",
    warpedStem = "minecraft:warped_stem",
    warpedWartblock = "minecraft:warped_wart_block",
    waterBucket = "minecraft:water_bucket",
    weepingVines = "minecraft:weeping_vines",
    weepingVinesPlant = "minecraft:weeping_vines_plant",
    wiredModem = "computercraft:wired_modem_full"
}

local fuelItems = {[ItemApi.lavaBucket] = 1000, [ItemApi.coal] = 80, [ItemApi.charcoal] = 80, [ItemApi.coalBlock] = 800}

---@type ItemDetails
local itemDetails = {}

---@param detail ItemDetail
function ItemApi.addItemDetail(detail)
    itemDetails[detail.name] = detail
end

---@param item string
function ItemApi.hasItemDetail(item)
    return itemDetails[item] ~= nil
end

---@return ItemDetails
function ItemApi.getItemDetails()
    return itemDetails
end

---@param item string
---@param default? integer
---@return integer
function ItemApi.getItemMaxCount(item, default)
    if not itemDetails[item] and not default then
        error(string.format("no max count available for item %s", item))
    end

    return itemDetails[item] and itemDetails[item].maxCount or default
end

---@param stock ItemStock
---@param defaultMaxCount? integer
---@return integer
function ItemApi.getRequiredSlotCount(stock, defaultMaxCount)
    local slotCount = 0

    for item, quantity in pairs(stock) do
        slotCount = slotCount + math.ceil(quantity / ItemApi.getItemMaxCount(item, defaultMaxCount))
    end

    return slotCount
end

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

---@param item string
---@return integer
function ItemApi.getRefuelAmount(item)
    if not fuelItems[item] then
        error(string.format("%s is not fuel", item))
    end

    return fuelItems[item]
end

return ItemApi
