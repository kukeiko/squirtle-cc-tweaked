package.path = package.path .. ";/?.lua"
package.path = package.path .. ";/app/turtle/?.lua"

local Rpc = require "lib.common.rpc"
local CrafterService = require "lib.services.crafter-service"

print("[io-crafter v1.0.0-dev] booting...")
Rpc.server(CrafterService)
