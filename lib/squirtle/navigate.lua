local Cardinal = require "elements.cardinal"
local PathFinding = require "scout.path-finding"
local orientate = require "squirtle.orientate"
local World = require "scout.world"
local Transform = require "scout.transform"
local inspect = require "squirtle.inspect"
local dig = require "squirtle.dig"
local refuel = require "squirtle.refuel"
local moveToPoint = require "squirtle.move.to-point"

---@param path Vector[]
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
---@param options? SquirtleMoveOptions
return function(to, world, breakable, options)
    -- [todo] remove breakable() in favor of options;
    -- also we could pass them along to walkPath(),
    -- which then could progress further before failing
    -- because it could now dig stuff
    breakable = breakable or function()
        return false
    end

    world = world or World.new(Transform.new(orientate()))
    local from, facing = orientate()

    while true do
        local path, msg = PathFinding.findPath(world, from, to, facing)

        if not path then
            return false, msg
        end

        local distance = PathFinding.manhattan(from, to)
        refuel(distance)
        local success, failedSide = walkPath(path)

        if success then
            -- print("[nav] success!")
            return true
        else
            from, facing = orientate()
            -- print(string.format("hit a block @ %s, scanning...", Side.getName(failedSide)))
            local block = inspect(failedSide)
            local scannedLocation = from + Cardinal.toVector(Cardinal.fromSide(failedSide, facing))

            if block and breakable(block) then
                dig(failedSide)
            elseif block then
                world:setBlock(scannedLocation)
            else
                error("could not move, not sure why")
            end
        end
    end
end
