local isCrops = require "farmer.is-crops"
local Squirtle = require "lib.squirtle"

local cropsReadyAges = {
    ["minecraft:wheat"] = 7,
    ["minecraft:beetroots"] = 3,
    ["minecraft:potatoes"] = 7,
    ["minecraft:carrots"] = 7
}

---@param side string
---@return integer
local function getCropsRemainingAge(side)
    local crops = Squirtle.probe(side)

    if not crops or not isCrops(crops) then
        error(string.format("expected block at %s to be crops", side))
    end

    local readyAge = cropsReadyAges[crops.name]

    if not readyAge then
        error(string.format("no ready age known for %s", crops.name))
    end

    return readyAge - crops.state.age
end

---@param side string
---@param max? integer if supplied, only wait if age difference does not exceed max
---@param time? integer maximum amount of time to wait
---@return boolean ready if crops are ready
return function(side, max, time)
    while getCropsRemainingAge(side) > 0 and Squirtle.selectItem("minecraft:bone_meal") and Squirtle.place(side) do
    end

    local remainingAge = getCropsRemainingAge(side)

    if max and remainingAge > max then
        return false
    end

    if remainingAge > 0 then
        print("waiting for crop to grow")
    end

    local waitUntilReady = function()
        while getCropsRemainingAge(side) > 0 do
            os.sleep(7)
        end
    end

    if time then
        return parallel.waitForAny(waitUntilReady, function()
            os.sleep(time)
        end) == 1
    end

    waitUntilReady()

    return true
end
