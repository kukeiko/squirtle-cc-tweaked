package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local SquirtleV2 = require "squirtle.squirtle-v2"
local boot = require "silo.boot"
local sequence = require "silo.sequence"

print("[silo v1.4.3] booting...")
local state = boot(arg)

if not state then
    return nil
end

SquirtleV2.simulate = true
sequence(state)
-- [todo] also require fuel based on steps taken
SquirtleV2.requireItems(SquirtleV2.results.placed)
print("all good now! building...")
SquirtleV2.simulate = false
sequence(state)