package.path = package.path .. ";/lib/?.lua"

local Fuel = require "squirtle.fuel"
local refuel = require "squirtle.refuel"
local locate = require "squirtle.locate"
local orientate = require "squirtle.orientate"

print(orientate())
