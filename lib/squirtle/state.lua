-- [todo] move to apis/turtle and remove usage from anyone but TurtleStateApi
local Cardinal = require "lib.models.cardinal"
local Vector = require "lib.models.vector"

---@class Simulated
---@field steps integer
---@field placed ItemStock
local SimulationResults = {placed = {}, steps = 0}
---
---@alias OrientationMethod "move"|"disk-drive"
---@alias DiskDriveOrientationSide "top" | "bottom"
---@alias MoveOrientationSide "front" | "back" | "left" | "right"
---@alias OrientationSide DiskDriveOrientationSide | MoveOrientationSide
---
---@class State
---@field breakable? fun(block: Block) : boolean
---@field facing integer
---@field position Vector
---@field orientationMethod OrientationMethod
---@field shulkerSides PlaceSide[]
---In which direction the turtle is allowed to try to break a block in order to place a shulker that could not be placed at front, top or bottom.
---@field breakDirection? "top"|"front"|"bottom"
---If right turns should be left turns and vice versa, useful for mirroring builds.
---@field flipTurns boolean
---@field results Simulated
---@field simulation Simulation?
local State = {
    facing = Cardinal.south,
    position = Vector.create(0, 0, 0),
    orientationMethod = "move",
    flipTurns = false,
    results = SimulationResults,
    shulkerSides = {"front", "top", "bottom"}
}

---@class Simulation
---@field current SimulationState
---@field target SimulationState?

return State
