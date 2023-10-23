package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Squirtle = require "squirtle"
local boot = require "bone-meal.boot"
local sequence = require "bone-meal.sequence"

print("[bone-meal v1.0.0] booting...")
local state = boot(arg)

if not state then
    return nil
end

Squirtle.simulate = true
sequence(state)
-- [todo] also require fuel based on steps taken
Squirtle.requireItems(Squirtle.results.placed)
print("all good now! building...")
Squirtle.simulate = false
sequence(state)
