package.path = package.path .. ";/lib/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Rpc = require "rpc"
local CrafterService = require "services.crafter-service"

print("[io-crafter v1.0.0-dev] booting...")
Rpc.server(CrafterService)
