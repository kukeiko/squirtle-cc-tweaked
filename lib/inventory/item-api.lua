local Utils = require "lib.tools.utils"

---@class ItemApi
local ItemApi = {
    barrel = "minecraft:barrel",
    beacon = "minecraft:beacon",
    beehive = "minecraft:beehive",
    beetrootSeeds = "minecraft:beetroot_seeds",
    birchLeaves = "minecraft:birch_leaves",
    birchLog = "minecraft:birch_log",
    birchPlanks = "minecraft:birch_planks",
    birchSapling = "minecraft:birch_sapling",
    boneMeal = "minecraft:bone_meal",
    bucket = "minecraft:bucket",
    charcoal = "minecraft:charcoal",
    chest = "minecraft:chest",
    coal = "minecraft:coal",
    coalBlock = "minecraft:coal_block",
    comparator = "minecraft:comparator",
    composter = "minecraft:composter",
    computer = "computercraft:computer_normal",
    copperBlock = "minecraft:copper_block",
    crimsonFungus = "minecraft:crimson_fungus",
    crimsongStem = "minecraft:crimson_stem",
    crimsonNylium = "minecraft:crimson_nylium",
    darkOakFence = "minecraft:dark_oak_fence",
    darkOakSlab = "minecraft:dark_oak_slab",
    darkOakStairs = "minecraft:dark_oak_stairs",
    diamondBlock = "minecraft:diamond_block",
    dirt = "minecraft:dirt",
    disk = "computercraft:disk",
    diskDrive = "computercraft:disk_drive",
    dispenser = "minecraft:dispenser",
    dropper = "minecraft:dropper",
    flowerPot = "minecraft:flower_pot",
    furnace = "minecraft:furnace",
    glassPane = "minecraft:glass_pane",
    goldBlock = "minecraft:gold_block",
    grassBlock = "minecraft:grass_block",
    hopper = "minecraft:hopper",
    ironBlock = "minecraft:iron_block",
    lantern = "minecraft:lantern",
    lavaBucket = "minecraft:lava_bucket",
    lectern = "minecraft:lectern",
    lever = "minecraft:lever",
    lightBlueBed = "minecraft:light_blue_bed",
    moss = "minecraft:moss_block",
    netheriteBlock = "minecraft:netherite_block",
    netheriteIngot = "minecraft:netherite_ingot",
    netherWartBlock = "minecraft:nether_wart_block",
    networkCable = "computercraft:cable",
    oakDoor = "minecraft:oak_door",
    oakFence = "minecraft:oak_fence",
    oakLeaves = "minecraft:oak_leaves",
    oakLog = "minecraft:oak_log",
    oakPlanks = "minecraft:oak_planks",
    oakSapling = "minecraft:oak_sapling",
    oakStairs = "minecraft:oak_stairs",
    oakTrapdoor = "minecraft:oak_trapdoor",
    observer = "minecraft:observer",
    poisonousPotato = "minecraft:poisonous_potato",
    piston = "minecraft:piston",
    poppy = "minecraft:poppy",
    redCarpet = "minecraft:red_carpet",
    redstone = "minecraft:redstone",
    redstoneBlock = "minecraft:redstone_block",
    redstoneTorch = "minecraft:redstone_torch",
    repeater = "minecraft:repeater",
    shroomlight = "minecraft:shroomlight",
    shulkerBox = "minecraft:shulker_box",
    smoothStone = "minecraft:smooth_stone",
    spruceDoor = "minecraft:spruce_door",
    spruceFence = "minecraft:spruce_fence",
    sprucePlanks = "minecraft:spruce_planks",
    spruceSlab = "minecraft:spruce_slab",
    spruceStairs = "minecraft:spruce_stairs",
    spruceTrapdoor = "minecraft:spruce_trapdoor",
    stick = "minecraft:stick",
    stickyPiston = "minecraft:sticky_piston",
    stone = "minecraft:stone",
    stoneBrickWall = "minecraft:stone_brick_wall",
    stoneStairs = "minecraft:stone_stairs",
    strippedOakLog = "minecraft:stripped_oak_log",
    strippedSpruceLog = "minecraft:stripped_spruce_log",
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
    wheatSeeds = "minecraft:wheat_seeds",
    wiredModem = "computercraft:wired_modem_full",
    wirelessModem = "computercraft:wireless_modem_normal"
}

local fuelItems = {[ItemApi.lavaBucket] = 1000, [ItemApi.coal] = 80, [ItemApi.charcoal] = 80, [ItemApi.coalBlock] = 800}

local cropsReadyAges = {["minecraft:wheat"] = 7, ["minecraft:beetroots"] = 3, ["minecraft:potatoes"] = 7, ["minecraft:carrots"] = 7}

local cropsToSeedsMap = {
    ["minecraft:wheat"] = "minecraft:wheat_seeds",
    ["minecraft:beetroots"] = "minecraft:beetroot_seeds",
    ["minecraft:potatoes"] = "minecraft:potato",
    ["minecraft:carrots"] = "minecraft:carrot"
}

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
---@return ItemStock
function ItemApi.filterIsMissingDetails(stock)
    ---@type ItemStock
    local unknown = {}

    for item, quantity in pairs(stock) do
        if not itemDetails[item] then
            unknown[item] = quantity
        end
    end

    return unknown
end

---How many slots the given stock of items would occupy.
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

---@return table<string, integer>
function ItemApi.getFuelItems()
    return Utils.copy(fuelItems)
end

---@param item string
---@return integer
function ItemApi.getRefuelAmount(item)
    if not fuelItems[item] then
        error(string.format("%s is not fuel", item))
    end

    return fuelItems[item]
end

---Returns the quantity of the given item needed to fulfill the given fuel.
---
---Throws an error if the given item is not fuel.
---@param item string
---@param fuel integer
---@return integer
function ItemApi.getRequiredRefuelCount(item, fuel)
    return math.ceil(fuel / ItemApi.getRefuelAmount(item))
end

---@param item string
---@return string
function ItemApi.getSeedsOfCrop(item)
    if not cropsToSeedsMap[item] then
        error(string.format("%s is not a crop", item))
    end

    return cropsToSeedsMap[item]
end

---@param crops Block
---@return integer
function ItemApi.getCropsRemainingAge(crops)
    if not ItemApi.isCropsBlock(crops) then
        error(string.format("block is not crops"))
    end

    local readyAge = cropsReadyAges[crops.name]

    if not readyAge then
        error(string.format("no ready age known for %s", crops.name))
    end

    return readyAge - crops.state.age
end

---@param block Block
---@return boolean
function ItemApi.isCropsBlock(block)
    return block.tags["minecraft:crops"]
end

return ItemApi
