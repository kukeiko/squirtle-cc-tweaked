local World = require "geo.world"
local findPath = require "geo.find-path"
local Inventory = require "inventory"
local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"
local State = require "squirtle.state"
local getNative = require "squirtle.get-native"
local Basic = require "squirtle.basic"
local Advanced = require "squirtle.advanced"
local Complex = require "squirtle.complex"
local requireItems = require "squirtle.require-items"

---@class Squirtle : Complex
local Squirtle = {inventorySize = 16}
setmetatable(Squirtle, {__index = Complex})

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function Squirtle.setBreakable(predicate)
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
function Squirtle.tryPut(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if State.simulate then
        return simulateTryPut(block)
    end

    if block then
        while not Squirtle.selectItem(block) do
            Squirtle.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while Squirtle.tryMine(side) do
    end

    return native()
end

---@param side? string
---@param block? string
function Squirtle.put(side, block)
    requireItem = requireItem or true

    if State.simulate then
        return simulatePut(block)
    end

    if not Squirtle.tryPut(side, block) then
        error("failed to place")
    end
end

---@param side string
---@return boolean success if everything could be dumped
function Squirtle.dump(side)
    local items = Squirtle.getStacks()

    for slot in pairs(items) do
        Squirtle.select(slot)
        Squirtle.drop(side)
    end

    return Squirtle.isEmpty()
end

function Squirtle.lookAtChest()
    Squirtle.turn(Inventory.findChest())
end

---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(alsoIgnoreSlot)
    for slot = 1, 16 do
        if alsoIgnoreSlot ~= slot then
            local item = Basic.getStack(slot)

            if item and item.name ~= "minecraft:shulker_box" then
                return slot
            end
        end
    end
end

---@param shulker integer
---@param item string
---@return boolean
local function loadFromShulker(shulker, item)
    Basic.select(shulker)

    local placedSide = Basic.placeFrontTopOrBottom()

    if not placedSide then
        return false
    end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = Inventory.getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            Advanced.suckSlot(placedSide, stackSlot)
            local emptySlot = Squirtle.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                Basic.select(slotToPutIntoShulker)
                Squirtle.drop(placedSide)
                Basic.select(shulker)
            end

            -- [todo] cannot use Squirtle.dig() cause breaking shulkers might not be allowed
            Squirtle.dig(placedSide)

            return true
        end
    end

    Squirtle.dig(placedSide)

    return false
end

---@param name string
---@return false|integer
function Squirtle.selectItem(name)
    if State.simulate then
        return false
    end

    local slot = Basic.find(name, true)

    if not slot then
        local nextShulkerSlot = 1

        while true do
            local shulker = Squirtle.find("minecraft:shulker_box", true, nextShulkerSlot)

            if not shulker then
                break
            end

            if loadFromShulker(shulker, name) then
                -- [note] we can return "shulker" here because the item loaded from the shulker box ends
                -- up in the slot the shulker originally was
                return shulker
            end

            nextShulkerSlot = nextShulkerSlot + 1
        end

        return false
    end

    Squirtle.select(slot)

    return slot
end

---@param items table<string, integer>
function Squirtle.requireItems(items)
    requireItems(items)
end

---@param target Vector
---@return boolean, string?
function Squirtle.walkToPoint(target)
    local delta = Vector.minus(target, Squirtle.locate())

    if delta.y > 0 then
        if not Squirtle.tryWalk("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not Squirtle.tryWalk("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        Squirtle.face(Cardinal.east)
        if not Squirtle.tryWalk("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        Squirtle.face(Cardinal.west)
        if not Squirtle.tryWalk("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        Squirtle.face(Cardinal.south)
        if not Squirtle.tryWalk("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        Squirtle.face(Cardinal.north)
        if not Squirtle.tryWalk("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param path Vector[]
---@return boolean, string?, integer?
local function walkPath(path)
    for i, next in ipairs(path) do
        local success, failedSide = Squirtle.walkToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
function Squirtle.navigate(to, world, breakable)
    breakable = breakable or function(...)
        return false
    end

    if not world then
        local position = Squirtle.locate()
        world = World.create(position.x, position.y, position.z)
    end

    local from, facing = Squirtle.orientate()

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        Squirtle.refuelTo(distance)
        local success, failedSide = walkPath(path)

        if success then
            return true
        elseif failedSide then
            from, facing = Squirtle.orientate()
            local block = Squirtle.probe(failedSide)
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))

            if block and breakable(block) then
                Squirtle.mine(failedSide)
            elseif block then
                World.setBlock(world, scannedLocation)
            else
                error("could not move, not sure why")
            end
        end
    end
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function Squirtle.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if Squirtle.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and Squirtle.tryWalk("up") then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and Squirtle.tryWalk("down") then
            strategy = "down"
            forbidden = "up"
        elseif Squirtle.turn("left") and Squirtle.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif Squirtle.turn("left") and forbidden ~= "back" and Squirtle.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        elseif Squirtle.turn("left") and Squirtle.tryWalk("forward") then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while Squirtle.tryWalk("forward") do
            end
        elseif strategy == "up" then
            while Squirtle.tryWalk("up") do
            end
        elseif strategy == "down" then
            while Squirtle.tryWalk("down") do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

return Squirtle
