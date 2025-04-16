local TurtleApi = require "lib.apis.turtle.turtle-api"
local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"
local World = require "lib.models.world"

local function printUsage()
    print("Usage:")
    print("dig <depth> <width> <height>")
    print("(negative numbers possible)")
end

---@param args table<string>
---@return DigAppState? state
return function(args)
    local depth = tonumber(args[1])
    local width = tonumber(args[2])
    local height = tonumber(args[3])
    ---@type table<string>
    local ignore = {}

    for i = 4, #args do
        table.insert(ignore, args[i])
    end

    if not depth or not width or not height or depth == 0 or width == 0 or height == 0 then
        printUsage()
        return nil
    end

    width = -width

    local returnTripFuel = math.abs(depth) + math.abs(width) + math.abs(height)
    local numBlocks = math.abs(depth) * math.abs(width) * math.abs(height)
    print(numBlocks .. "x blocks, guessing " .. numBlocks / 32 .. " stacks")

    local requiredFuel = math.ceil((numBlocks + returnTripFuel) * 1.2)
    TurtleApi.refuelTo(requiredFuel)

    local position = Vector.create(0, 0, 0)
    -- [todo] rotate world around actual facing
    local facing = Cardinal.south
    local worldX = 0
    local worldY = 0
    local worldZ = 0

    if width < 0 then
        worldX = position.x + width + 1
        width = math.abs(width)
    end

    if height < 0 then
        worldY = position.y + height + 1
        height = math.abs(height)
    end

    if depth < 0 then
        worldZ = position.z + depth + 1
        depth = math.abs(depth)
    end

    local world = World.create(worldX, worldY, worldZ, width, height, depth)
    local hasShulkers = false

    for slot = 1, 16 do
        local stack = turtle.getItemDetail(slot)
        if stack and stack.name:match("shulker") then
            hasShulkers = true
            break
        end
    end

    return {position = position, facing = facing, world = world, hasShulkers = hasShulkers, ignore = ignore}
end
