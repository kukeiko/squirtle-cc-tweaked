package.path = package.path .. ";/?.lua"

local Cardinal = require "squirtle.libs.cardinal"
local Vector = require "squirtle.libs.vector"
local Turtle = require "squirtle.libs.turtle"
local Utils = require "squirtle.libs.utils"

---@class State
---@field foundationPerimeterBuilt boolean
---@field farmLocation Vector
---@field farmRotation integer

local statePath = "/state/apps/turtle/farmer.json"

local wheatName = "minecraft:wheat" -- harvest at state.age 7

---@return State
local function loadStateFromDisk(defaultState)
    local state = defaultState or {}

    if fs.exists(statePath) then
        local file = fs.open(statePath, "r")
        local stateOnDisk, message = textutils.unserializeJSON(file.readAll())
        file.close()

        if not stateOnDisk then
            error(message)
        end

        for key, value in pairs(stateOnDisk) do
            state[key] = value
        end

    end

    return state
end

local function saveStateToDisk(state)
    local file = fs.open(statePath, "w")
    file.write(textutils.serializeJSON(state))
    file.close()
end

local function main(args)
    print("[farmer @ 1.0.0]")
    local state = loadStateFromDisk({})
    local orientation, position = Turtle.orientate()

    if not state.farmLocation then
        print("no farm world location saved. assuming current location as farm location")
        state.farmLocation = position
        state.farmRotation = orientation
        saveStateToDisk(state)
    else
        state.farmLocation = Vector.cast(state.farmLocation)
    end

    print("farm location is", state.farmLocation)
    print("farm rotation is", state.farmRotation)

    if not state.foundationPerimeterBuilt then
        print("perimeter not built yet")

        if position:equals(state.farmLocation) then
            print("i am at home, assuming we never started building perimeter")
            -- require 40 grass blocks and a pickaxe
        end

    end

    -- local orientation, position = Turtle.orientate()
    -- local farmRotation = orientation
    -- local farmPosition = position

    -- -- rotate right to transform local to world
    -- print("# local -> world")
    -- print("south =>", Cardinal.getName(Cardinal.rotateRight(Cardinal.south, farmRotation)))
    -- print("west =>", Cardinal.getName(Cardinal.rotateRight(Cardinal.west, farmRotation)))
    -- print("north =>", Cardinal.getName(Cardinal.rotateRight(Cardinal.north, farmRotation)))
    -- print("east =>", Cardinal.getName(Cardinal.rotateRight(Cardinal.east, farmRotation)))
    -- -- rotate left to transform world to local
    -- print("# world -> local")
    -- print("south =>", Cardinal.getName(Cardinal.rotateLeft(Cardinal.south, farmRotation)))
    -- print("west =>", Cardinal.getName(Cardinal.rotateLeft(Cardinal.west, farmRotation)))
    -- print("north =>", Cardinal.getName(Cardinal.rotateLeft(Cardinal.north, farmRotation)))
    -- print("east =>", Cardinal.getName(Cardinal.rotateLeft(Cardinal.east, farmRotation)))

    -- local vecNorthEast = Vector.new(1, 0, -1)
    -- local vecSouthEast = Vector.new(1, 0, 1)
    -- local vecSouthWest = Vector.new(-1, 0, 1)
    -- local vecNorthWest = Vector.new(-1, 0, -1)

    -- print(vecNorthEast:rotateRight(0), vecNorthEast)
    -- print(vecNorthEast:rotateRight(1), vecSouthEast)
    -- print(vecNorthEast:rotateRight(2), vecSouthWest)
    -- print(vecNorthEast:rotateRight(3), vecNorthWest)

    -- print(vecNorthEast:rotateLeft(0), vecNorthEast)
    -- print(vecNorthEast:rotateLeft(1), vecNorthWest)
    -- print(vecNorthEast:rotateLeft(2), vecSouthWest)
    -- print(vecNorthEast:rotateLeft(3), vecSouthEast)
end

main()
