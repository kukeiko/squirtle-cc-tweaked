if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

package.path = package.path .. ";/app/turtle/?.lua"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local boot = require "silo.boot"
local sequence = require "silo.sequence"

print(string.format("[silo %s] booting...", version()))
local state = boot(arg)

if not state then
    return nil
end

-- [note] importante when making resumability easier to use:
-- orientate() relies on Simulation being inactive - otherwise placing the disk drive would be simulated :D

local results = TurtleApi.simulate(function()
    sequence(state)
end)

TurtleApi.requireItems(results.placed)
TurtleApi.refuelTo(results.steps)
print("[ok] all good now! building...")
sequence(state)
