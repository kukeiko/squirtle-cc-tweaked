package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Utils = require "utils"
local World = require "geo.world"
local nextPoint = require "dig.next-point"
local boot = require "dig.boot"
local SquirtleV2 = require "squirtle.squirtle-v2"

---@class DigAppState
---@field world World
---@field position Vector
---@field facing integer
---@field hasShulkers boolean
---@field ignore table<string>

local function isGettingFull()
    return turtle.getItemCount(16) > 0
end

---@param world World
---@param position Vector
local function digUpDownIfInBounds(world, position)
    if World.isInBoundsY(world, position.y + 1) then
        SquirtleV2.tryDig("up")
    end

    if World.isInBoundsY(world, position.y - 1) then
        SquirtleV2.tryDig("down")
    end
end

---@return string? direction
local function placeAnywhere()
    if turtle.place() then
        return "front"
    end

    if turtle.placeUp() then
        return "up"
    end

    if turtle.placeDown() then
        return "down"
    end
end

---@param direction string
---@return boolean unloadedAll
local function loadIntoShulker(direction)
    local unloadedAll = true

    for slot = 1, 16 do
        local stack = SquirtleV2.getStack(slot)

        if stack and not stack.name:match("shulker") then
            SquirtleV2.selectSlot(slot)
            if not SquirtleV2.drop(direction) then
                unloadedAll = false
            end
        end
    end

    return unloadedAll
end

---@return boolean unloadedAll
local function tryLoadShulkers()
    ---@type string?
    local placedSide = nil

    for slot = 1, 16 do
        local stack = SquirtleV2.getStack(slot)

        if stack and stack.name:match("shulker") then
            SquirtleV2.selectSlot(slot)
            placedSide = placeAnywhere()

            if not placedSide then
                print("failed to place shulker, no space :(")
                -- [todo] bit of an issue returning false here - shulkers might have enough space for items,
                -- yet we effectively return "shulkers are full" just because we couldn't place it
                -- however, this should only be an issue when digging a 1-high layer
                return false
            else
                local unloadedAll = loadIntoShulker(placedSide)
                SquirtleV2.selectSlot(slot)
                SquirtleV2.dig(placedSide)

                if unloadedAll then
                    return true
                end
            end
        end
    end

    return false
end
---@param args table<string>
---@return boolean
local function main(args)
    print("[dig v3.0.0] booting...")
    local state = boot(args)

    if not state then
        return false
    end

    print(string.format("[area] %dx%dx%d", state.world.depth, state.world.width, state.world.height))

    if #state.ignore > 0 then
        print("[ignore] " .. table.concat(state.ignore, ", "))
    end

    ---@type Vector|nil
    local point = state.position
    local start = state.position
    local world = state.world
    local facing = state.facing
    local shulkersFull = false
    turtle.select(1)

    ---@param block Block
    ---@return boolean
    local isBreakable = function(block)
        if #state.ignore == 0 then
            return true
        end

        return not Utils.find(state.ignore, function(item)
            return string.match(block.name, item)
        end)
    end

    local restoreBreakable = SquirtleV2.setBreakable(isBreakable)

    while point do
        if SquirtleV2.navigate(point, world, isBreakable) then
            digUpDownIfInBounds(world, point)

            if state.hasShulkers and not shulkersFull and isGettingFull() then
                shulkersFull = not tryLoadShulkers()
                turtle.select(1)
            end
        end

        point = nextPoint(point, world, start)
    end

    if state.hasShulkers and not shulkersFull then
        tryLoadShulkers()
    end

    restoreBreakable()
    print("[done] going home!")
    SquirtleV2.navigate(start, world, isBreakable)
    SquirtleV2.face(facing)

    return true
end

return main(arg)
