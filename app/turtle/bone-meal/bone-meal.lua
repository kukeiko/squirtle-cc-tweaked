if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Turtle = require "lib.squirtle.squirtle-api"
local boot = require "bone-meal.boot"
local sequence = require "bone-meal.sequence"

print(string.format("[bone-meal %s] booting...", version()))
local state = boot(arg)

if not state then
    return nil
end

Turtle.beginSimulation()
sequence(state)
Turtle.recordPlacedBlock(state.blocks.waterBucket, 2)
Turtle.recordPlacedBlock(state.blocks.lavaBucket, 1)
Turtle.recordPlacedBlock(state.blocks.boneMeal, 64)
local results = Turtle.endSimulation()
Turtle.refuelTo(results.steps)
Turtle.requireItems(results.placed)
print("[ok] all good now! building...")
local home = Turtle.getPosition()
local facing = Turtle.getFacing()
sequence(state)
Turtle.navigate(home)
Turtle.face(facing)
