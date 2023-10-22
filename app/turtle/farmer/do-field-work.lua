local Backpack = require "squirtle.backpack"
local isCrops = require "farmer.is-crops"
local place = require "squirtle.place"
local selectItem = require "squirtle.backpack.select-item"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"
local SquirtleV2 = require "squirtle.squirtle-v2"

local cropsToSeedsMap = {
    ["minecraft:wheat"] = "minecraft:wheat_seeds",
    ["minecraft:beetroots"] = "minecraft:beetroot_seeds",
    ["minecraft:potatoes"] = "minecraft:potato",
    ["minecraft:carrots"] = "minecraft:carrot"
}

local function tryPlantAnything()
    for slot = 1, Backpack.size() do
        if Backpack.selectSlotIfNotEmpty(slot) then
            if SquirtleV2.tryPlace("bottom") then
                return
            end
        end
    end
end

---@param crops string
---@return false|integer
local function selectSlotWithSeedsOfCrop(crops)
    local seeds = cropsToSeedsMap[crops]

    if not seeds then
        return false
    end

    return selectItem(seeds)
end

---@param block Block
local function harvestCrops(block)
    if waitUntilCropsReady("bottom", 2, (7 * 3) + 1) then
        local selectedSeed = selectSlotWithSeedsOfCrop(block.name)

        if not selectedSeed then
            Backpack.selectFirstEmptySlot()
            -- [todo] error handling
        end

        SquirtleV2.dig("down")

        if not SquirtleV2.tryPlace("bottom") then
            tryPlantAnything()
        end
    end
end

---@param block Block?
return function(block)
    if block and isCrops(block) then
        harvestCrops(block)
    elseif not block then
        turtle.digDown()
        tryPlantAnything()
    end
end
