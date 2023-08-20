package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local SquirtleV2 = require "squirtle.squirtle-v2"
local boot = require "silo.boot"
local sequence = require "silo.sequence"
local requireItems = require "squirtle.require-items"

print("[silo v1.4.0] booting...")
local state = boot(arg)

if not state then
    return nil
end

SquirtleV2.simulate = true
sequence(state)
requireItems(SquirtleV2.results.blocksPlaced)
print("all good now! building...")
SquirtleV2.simulate = false
sequence(state)
