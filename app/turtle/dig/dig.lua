package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local World = require "geo.world"
local navigate = require "squirtle.navigate"
local dig = require "squirtle.dig"
local face = require "squirtle.face"
local nextPoint = require "dig.next-point"
local boot = require "dig.boot"
local drop = require "squirtle.drop"

---@class DigAppState
---@field world World
---@field position Vector
---@field facing integer
---@field hasShulkers boolean

local function isGettingFull()
    return turtle.getItemCount(16) > 0
end

---@param world World
---@param position Vector
local function digUpDownIfInBounds(world, position)
    if World.isInBoundsY(world, position.y + 1) then
        dig("top")
    end

    if World.isInBoundsY(world, position.y - 1) then
        dig("bottom")
    end
end

local function isBreakable(block)
    if not block then
        return false
    end

    return true
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
        local stack = turtle.getItemDetail(slot)

        if stack and not stack.name:match("shulker") then
            turtle.select(slot)
            if not drop(direction) then
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
        local stack = turtle.getItemDetail(slot)

        if stack and stack.name:match("shulker") then
            turtle.select(slot)
            placedSide = placeAnywhere()

            if not placedSide then
                print("failed to place shulker, no space :(")
                -- [todo] bit of an issue returning false here - shulkers might have enough space for items,
                -- yet we effectively return "shulkers are full" just because we couldn't place it
                -- however, this should only be an issue when digging a 1-high layer
                return false
            else
                local unloadedAll = loadIntoShulker(placedSide)
                turtle.select(slot)
                dig(placedSide)

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
    print("[dig v2.0.0] booting...")
    local state = boot(args)

    if not state then
        return false
    end

    ---@type Vector|nil
    local point = state.position
    local start = state.position
    local world = state.world
    local facing = state.facing
    local shulkersFull = false
    turtle.select(1)

    while point do
        if navigate(point, world, isBreakable) then
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

    print("[done] going home!")
    navigate(start, world, isBreakable)
    face(facing)

    return true
end

return main(arg)
