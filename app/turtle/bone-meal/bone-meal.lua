if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local Squirtle = require "lib.squirtle.squirtle-api"
local SquirtleState = require "lib.squirtle.state"
local boot = require "bone-meal.boot"
local sequence = require "bone-meal.sequence"

print(string.format("[bone-meal %s] booting...", version()))
local state = boot(arg)

if not state then
    return nil
end

SquirtleState.simulate = true
sequence(state)
-- [todo] also require fuel based on steps taken
SquirtleState.results.placed[state.blocks.waterBucket] = 2
SquirtleState.results.placed[state.blocks.lavaBucket] = 1
SquirtleState.results.placed[state.blocks.boneMeal] = 64
SquirtleState.simulate = false
Squirtle.requireItems(SquirtleState.results.placed)
print("[ok] all good now! building...")
local home = Squirtle.getPosition()
local facing = Squirtle.getFacing()
sequence(state)
Squirtle.navigate(home)
Squirtle.face(facing)
