local Utils = require "lib.common.utils"
local World = require "lib.common.world"
local findPath = require "lib.squirtle.find-path"
local Inventory = require "lib.inventory.inventory-api"
local Cardinal = require "lib.common.cardinal"
local Vector = require "lib.common.vector"
local State = require "lib.squirtle.state"
local getNative = require "lib.squirtle.get-native"
local Basic = require "lib.squirtle.api-layers.squirtle-basic-api"
local Advanced = require "lib.squirtle.api-layers.squirtle-advanced-api"
local Complex = require "lib.squirtle.api-layers.squirtle-complex-api"
local requireItems = require "lib.squirtle.require-items"

---@class SquirtleApi : SquirtleComplexApi
local SquirtleApi = {}
setmetatable(SquirtleApi, {__index = Complex})

--- [todo] rework to not accept a predicate. also somehow support block tags (see isCrops() from farmer)
---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function SquirtleApi.setBreakable(predicate)
    return State.setBreakable(predicate)
end

---@param block? string
---@return boolean
local function simulateTryPut(block)
    if block then
        if not State.results.placed[block] then
            State.results.placed[block] = 0
        end

        State.results.placed[block] = State.results.placed[block] + 1
    end

    return true
end

---@param block? string
local function simulatePut(block)
    simulateTryPut(block)
end

---@param side? string
---@param block? string
---@return boolean
function SquirtleApi.tryPut(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if State.simulate then
        return simulateTryPut(block)
    end

    if block then
        while not SquirtleApi.selectItem(block) do
            SquirtleApi.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while SquirtleApi.tryMine(side) do
    end

    -- [todo] band-aid fix
    while turtle.attack() do
        os.sleep(1)
    end

    return native()
end

---@param side? string
---@param block? string
function SquirtleApi.put(side, block)
    if State.simulate then
        return simulatePut(block)
    end

    if not SquirtleApi.tryPut(side, block) then
        error("failed to place")
    end
end

---@param side string
---@return boolean success if everything could be dumped
function SquirtleApi.dump(side)
    local items = SquirtleApi.getStacks()

    for slot in pairs(items) do
        SquirtleApi.select(slot)
        SquirtleApi.drop(side)
    end

    return SquirtleApi.isEmpty()
end

function SquirtleApi.lookAtChest()
    SquirtleApi.turn(Inventory.findChest())
end

---@param items table<string, integer>
---@param shulker boolean?
function SquirtleApi.requireItems(items, shulker)
    requireItems(items, shulker)
end

---@param target Vector
---@return boolean, string?
function SquirtleApi.moveToPoint(target)
    local delta = Vector.minus(target, SquirtleApi.locate())

    if delta.y > 0 then
        if not SquirtleApi.tryMove("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not SquirtleApi.tryMove("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        SquirtleApi.face(Cardinal.east)
        if not SquirtleApi.tryMove("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        SquirtleApi.face(Cardinal.west)
        if not SquirtleApi.tryMove("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        SquirtleApi.face(Cardinal.south)
        if not SquirtleApi.tryMove("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        SquirtleApi.face(Cardinal.north)
        if not SquirtleApi.tryMove("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param path Vector[]
---@return boolean, string?, integer?
local function movePath(path)
    for i, next in ipairs(path) do
        local success, failedSide = SquirtleApi.moveToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
function SquirtleApi.navigate(to, world, breakable)
    breakable = breakable or function()
        return false
    end

    local restoreBreakable = SquirtleApi.setBreakable(breakable)

    if not world then
        local position = Complex.locate()
        world = World.create(position.x, position.y, position.z)
    end

    local from, facing = Complex.orientate()

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            restoreBreakable()
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        Advanced.refuelTo(distance)
        local success, failedSide = movePath(path)

        if success then
            restoreBreakable()
            return true
        elseif failedSide then
            from, facing = SquirtleApi.orientate()
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))
            World.setBlock(world, scannedLocation)
        end
    end
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function SquirtleApi.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and SquirtleApi.tryWalk("up") then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and SquirtleApi.tryWalk("down") then
            strategy = "down"
            forbidden = "up"
        elseif SquirtleApi.turn("left") and SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif SquirtleApi.turn("left") and forbidden ~= "back" and SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif SquirtleApi.turn("left") and SquirtleApi.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while SquirtleApi.tryWalk("forward") do
            end
        elseif strategy == "up" then
            while SquirtleApi.tryWalk("up") do
            end
        elseif strategy == "down" then
            while SquirtleApi.tryWalk("down") do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

---@param initial SimulationDetails?
---@param target SimulationDetails?
function SquirtleApi.simulate(initial, target)
    State.simulate = true
    State.simulation.initial = initial
    State.simulation.target = target

    if initial then
        State.simulation.current = Utils.clone(initial)
    else
        State.simulation.current = nil
    end

    State.checkResumeEnd()
end

---@class SquirtleConfigOptions
---@field orientate? "move"|"disk-drive"
---@field breakDirection? "top"|"front"|"bottom"
---@param options SquirtleConfigOptions
function SquirtleApi.configure(options)
    if options.orientate then
        State.orientationMethod = options.orientate
    end

    if options.breakDirection then
        State.breakDirection = options.breakDirection
    end
end

function SquirtleApi.recover()
    local diskDriveDirections = {"top", "bottom"}

    for _, direction in pairs(diskDriveDirections) do
        if Basic.probe(direction, "computercraft:disk_drive") then
            Basic.dig(direction)
        end
    end

    local shulkerDirections = {"top", "bottom", "front"}

    for _, direction in pairs(shulkerDirections) do
        if Basic.probe(direction, "minecraft:shulker_box") then
            Basic.dig(direction)
        end
    end
end

return SquirtleApi
