local Squirtle = require "squirtle"
local isCrops = require "farmer.is-crops"
local waitUntilCropsReady = require "farmer.wait-until-crops-ready"

local cropsToSeedsMap = {
    ["minecraft:wheat"] = "minecraft:wheat_seeds",
    ["minecraft:beetroots"] = "minecraft:beetroot_seeds",
    ["minecraft:potatoes"] = "minecraft:potato",
    ["minecraft:carrots"] = "minecraft:carrot"
}

local function tryPlantAnything()
    for slot = 1, Squirtle.size() do
        if Squirtle.selectSlotIfNotEmpty(slot) then
            if Squirtle.tryPlace("bottom") then
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

    return Squirtle.select(seeds)
end

---@param block Block
local function harvestCrops(block)
    if waitUntilCropsReady("bottom", 2, (7 * 3) + 1) then
        local selectedSeed = selectSlotWithSeedsOfCrop(block.name)

        if not selectedSeed then
            Squirtle.selectFirstEmptySlot()
            -- [todo] error handling
        end

        Squirtle.dig("down")

        if not Squirtle.tryPlace("bottom") then
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
