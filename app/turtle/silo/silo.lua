package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "lib.squirtle.squirtle-api"
local SquirtleState = require "lib.squirtle.state"
local boot = require "silo.boot"
local sequence = require "silo.sequence"

print("[silo v1.4.3] booting...")
local state = boot(arg)

if not state then
    return nil
end

--[note] importante when making resumability easier to use:
-- orientate() relies on Simulation being inactive - otherwise placing the disk drive would be simulated :D

SquirtleState.simulate = true
sequence(state)
-- [todo] also require fuel based on steps taken
Squirtle.requireItems(SquirtleState.results.placed)
print("all good now! building...")
SquirtleState.simulate = false
sequence(state)
