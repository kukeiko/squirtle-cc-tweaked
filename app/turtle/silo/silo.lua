package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "squirtle.squirtle"
local SimulatedSquirtle = require "squirtle.simulated-squirtle"
local boot = require "silo.boot"
local sequence = require "silo.sequence"
local requireItems = require "squirtle.require-items"

print("[silo v1.3.0] booting...")
local state = boot(arg)

if not state then
    return nil
end

local squirtle = SimulatedSquirtle:new(Squirtle:new())
squirtle.simulate = true
sequence(squirtle, state)

requireItems(squirtle.blocksPlaced)

print("all good now! building...")
