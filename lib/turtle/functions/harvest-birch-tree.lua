local ItemApi = require "lib.inventory.item-api"

---@param TurtleApi TurtleApi
local function digLeftAndRight(TurtleApi)
    TurtleApi.turn("left")
    TurtleApi.tryMine()
    TurtleApi.suck()
    TurtleApi.turn("right")
    TurtleApi.turn("right")
    TurtleApi.tryMine()
    TurtleApi.suck()
    TurtleApi.turn("left")
end

---@param TurtleApi TurtleApi
local function digUpAndDown(TurtleApi)
    TurtleApi.dig("up")
    TurtleApi.dig("down")
end

---@param TurtleApi TurtleApi
local function digSuckMove(TurtleApi)
    TurtleApi.tryMine()
    TurtleApi.suck()
    TurtleApi.move()
end

---@param TurtleApi TurtleApi
---@param leftAndRightOnFirstStep? boolean
local function moveOutAndCutLeaves(TurtleApi, leftAndRightOnFirstStep)
    leftAndRightOnFirstStep = leftAndRightOnFirstStep or false
    digSuckMove(TurtleApi)
    digUpAndDown(TurtleApi)

    if leftAndRightOnFirstStep then
        digLeftAndRight(TurtleApi)
    end

    digSuckMove(TurtleApi)
    digUpAndDown(TurtleApi)
    digLeftAndRight(TurtleApi)
    TurtleApi.walk("back", 2)
end

---@param TurtleApi TurtleApi
local function digAllSides(TurtleApi)
    for _ = 1, 4 do
        TurtleApi.tryMine()
        TurtleApi.turn("left")
    end
end

---@param TurtleApi TurtleApi
---@param minSaplings integer
local function collectSaplings(TurtleApi, minSaplings)
    if not TurtleApi.has(ItemApi.birchSapling, minSaplings) then
        for i = 1, 4 do
            moveOutAndCutLeaves(TurtleApi, i % 2 == 1)
            TurtleApi.turn("left")
        end
    end
end

---@param TurtleApi TurtleApi
---@param minSaplings? integer
return function(TurtleApi, minSaplings)
    print("[harvest] birch tree...")
    minSaplings = minSaplings or 32

    while TurtleApi.probe("top", ItemApi.birchLog) do
        TurtleApi.move("up")

        if TurtleApi.probe("front", ItemApi.birchLeaves) then
            digAllSides(TurtleApi)
        end
    end

    TurtleApi.move("up") -- goto peak
    digAllSides(TurtleApi) -- dig peak
    TurtleApi.move("down", 2)
    collectSaplings(TurtleApi, minSaplings)
    TurtleApi.move("down")
    collectSaplings(TurtleApi, minSaplings)

    while TurtleApi.tryWalk("down") do
    end
end
