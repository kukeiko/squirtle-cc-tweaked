package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "lib.squirtle"
local SquirtleState = require "lib.squirtle.state"
local boot = require "bone-meal.boot"
local sequence = require "bone-meal.sequence"

print("[bone-meal v2.1.0] booting...")
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
local home, facing = Squirtle.orientate()
sequence(state)
Squirtle.navigate(home)
Squirtle.face(facing)
