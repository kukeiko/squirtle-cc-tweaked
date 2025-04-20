if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local boot = require "bone-meal.boot"
local sequence = require "bone-meal.sequence"

print(string.format("[bone-meal %s] booting...", version()))
local state = boot(arg)

if not state then
    return nil
end

local results = TurtleApi.simulate(function()
    sequence(state)
    TurtleApi.recordPlacedBlock(state.blocks.waterBucket, 2)
    TurtleApi.recordPlacedBlock(state.blocks.lavaBucket, 1)
    TurtleApi.recordPlacedBlock(state.blocks.boneMeal, 64)
end)

TurtleApi.refuelTo(results.steps)
TurtleApi.requireItems(results.placed)
print("[ok] all good now! building...")
local home = TurtleApi.getPosition()
local facing = TurtleApi.getFacing()
sequence(state)
TurtleApi.navigate(home)
TurtleApi.face(facing)
