-- [todo] rename file to "turtle-api.lua" and move to apis/turtle
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local TurtleSharedApi = require "lib.apis.turtle.turtle-shared-api"
local TurtleInventoryApi = require "lib.apis.turtle.turtle-inventory-api"
local TurtleMiningApi = require "lib.apis.turtle.turtle-mining-api"
local TurtleBuildingApi = require "lib.apis.turtle.turtle-building-api"
local TurtleMovementApi = require "lib.apis.turtle.turtle-movement-api"
local TurtleLocationApi = require "lib.apis.turtle.turtle-location-api"
local TurtleSystemApi = require "lib.apis.turtle.turtle-system-api"

local requireItems = require "lib.apis.turtle.functions.require-items"
local placeShulker = require "lib.apis.turtle.functions.place-shulker"
local digShulker = require "lib.apis.turtle.functions.dig-shulker"

---@class TurtleApi : TurtleStateApi, TurtleSharedApi, TurtleInventoryApi, TurtleMiningApi, TurtleBuildingApi, TurtleMovementApi, TurtleLocationApi, TurtleSystemApi
local TurtleApi = {}

local components = {
    TurtleStateApi,
    TurtleSharedApi,
    TurtleInventoryApi,
    TurtleMiningApi,
    TurtleMiningApi,
    TurtleBuildingApi,
    TurtleMovementApi,
    TurtleLocationApi,
    TurtleSystemApi
}

setmetatable(TurtleApi, {
    __index = function(_, key)
        -- [todo] instead of runtime lookup, iterate over all components and just copy over the methods once.
        for i = 1, #components do
            local value = components[i][key]

            if value then
                return value
            end
        end
    end
})

TurtleSharedApi.setRequireItems(requireItems)
TurtleSharedApi.setPlaceShulker(placeShulker)
TurtleSharedApi.setDigShulker(digShulker)

return TurtleApi
