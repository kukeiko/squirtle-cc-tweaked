local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"
local findPath = require "geo.find-path"
local SquirtleV2 = require "squirtle.squirtle-v2"
local World = require "geo.world"
local dig = require "squirtle.dig"
local refuel = require "squirtle.refuel"
local moveToPoint = require "squirtle.move.to-point"

---@param path Vector[]
---@return boolean, string?, integer?
local function walkPath(path)
    for i, next in ipairs(path) do
        local success, failedSide = moveToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
return function(to, world, breakable)
    -- [todo] remove breakable() in favor of options;
    -- also we could pass them along to walkPath(),
    -- which then could progress further before failing
    -- because it could now dig stuff
    breakable = breakable or function(...)
        return false
    end

    if not world then
        local position = SquirtleV2.locate(true)
        world = World.create(position.x, position.y, position.z)
    end

    local from, facing = SquirtleV2.orientate(true)

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        refuel(distance)
        local success, failedSide = walkPath(path)

        if success then
            return true
        elseif failedSide then
            from, facing = SquirtleV2.orientate()
            local block = SquirtleV2.inspect(failedSide)
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))

            if block and breakable(block) then
                dig(failedSide)
            elseif block then
                World.setBlock(world, scannedLocation)
            else
                error("could not move, not sure why")
            end
        end
    end
end
