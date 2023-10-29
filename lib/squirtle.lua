local Utils = require "utils"
local World = require "geo.world"
local findPath = require "geo.find-path"
local Inventory = require "inventory.inventory"
local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"
local State = require "squirtle.state"
local getNative = require "squirtle.get-native"
local Elemental = require "squirtle.elemental"
local Basic = require "squirtle.basic"
local Advanced = require "squirtle.advanced"
local Complex = require "squirtle.complex"

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
    local slot = Basic.find(name)

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

-- [todo] add remaining
local itemMaxCounts = {["minecraft:lava_bucket"] = 1, ["minecraft:water_bucket"] = 1, ["minecraft:bucket"] = 16}

---@param item string
---@return integer
local function getItemMaxCount(item)
    return itemMaxCounts[item] or 64
end

---@param items table<string, integer>
---@return integer
local function itemsToStacks(items)
    local numStacks = 0

    for item, numItems in pairs(items) do
        numStacks = numStacks + math.ceil(numItems / getItemMaxCount(item))
    end

    return numStacks
end

---@param items table<string, integer>
local function getMissing(items)
    ---@type table<string, integer>
    local open = {}
    local stock = Squirtle.getStock()

    for item, required in pairs(items) do
        local missing = required - (stock[item] or 0)

        if missing > 0 then
            open[item] = required - (stock[item] or 0)
        end
    end

    return open
end

---@param items table<string, integer>
---@param shulker string
local function getMissingInShulker(items, shulker)
    ---@type table<string, integer>
    local open = {}
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(peripheral.call(shulker, "list")) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    for item, required in pairs(items) do
        local missing = required - (stock[item] or 0)

        if missing > 0 then
            open[item] = required - (stock[item] or 0)
        end
    end

    return open
end

---@param items table<string, integer>
---@param shulker string
local function fillShulker(items, shulker)
    while not peripheral.isPresent(shulker) do
        os.sleep(.1)
    end

    while true do
        ---@type table<string, integer>
        local open = getMissingInShulker(items, shulker)

        if Utils.count(open) == 0 then
            term.clear()
            term.setCursorPos(1, 1)
            return nil
        end

        term.clear()
        term.setCursorPos(1, 1)
        print("Required Items")
        local width = term.getSize()
        print(string.rep("-", width))

        for item, missing in pairs(open) do
            print(string.format("%dx %s", missing, item))
        end

        os.pullEvent("turtle_inventory")

        for slot = 1, 16 do
            local item = Elemental.getStack(slot)

            if item and item.name ~= "minecraft:shulker_box" then
                Elemental.select(slot)
                Squirtle.drop(shulker)
            end
        end
    end
end

-- [todo] assumes that everything stacks to 64
---@param items table<string, integer>
---@param numStacks integer
---@return table<string, integer>, table<string, integer>
local function sliceNumStacksFromItems(items, numStacks)
    ---@type table<string, integer>
    local sliced = {}
    local remainingStacks = numStacks
    local leftOver = Utils.copy(items)

    for item, count in pairs(items) do
        local slicedCount = math.min(count, remainingStacks * getItemMaxCount(item))
        sliced[item] = slicedCount
        leftOver[item] = leftOver[item] - slicedCount

        if leftOver[item] == 0 then
            leftOver[item] = nil
        end

        remainingStacks = remainingStacks - math.ceil(slicedCount / getItemMaxCount(item))

        if remainingStacks == 0 then
            break
        end
    end

    return sliced, leftOver
end

---@param items table<string, integer>
local function requireItemsNoShulker(items)
    while true do
        ---@type table<string, integer>
        local open = getMissing(items)

        if Utils.count(open) == 0 then
            term.clear()
            term.setCursorPos(1, 1)
            return nil
        end

        term.clear()
        term.setCursorPos(1, 1)
        print("Required Items")
        local width = term.getSize()
        print(string.rep("-", width))

        for item, missing in pairs(open) do
            print(string.format("%dx %s", missing, item))
        end

        os.pullEvent("turtle_inventory")
    end
end

---@param items table<string, integer>
local function requireItemsUsingShulker(items)
    local numStacks = itemsToStacks(items)
    -- shulkers have 27 slots, but we want to keep one slot empty per shulker
    -- so that suckSlot() doesn't have to temporarily load an item
    -- from the shulker into the turtle inventory
    local numShulkers = math.ceil(numStacks / 26)

    -- [todo] assumes an empty inventory
    if numShulkers > 15 then
        error("required items would need more than 15 shulker boxes")
    end

    requireItemsNoShulker({["minecraft:shulker_box"] = numShulkers})

    local fullShulkers = {}
    local theItems = Utils.copy(items)

    for i = 1, numShulkers do
        for slot = 1, 16 do
            local item = Elemental.getStack(slot, true)

            if item and item.name == "minecraft:shulker_box" and not fullShulkers[item.nbt] then
                Elemental.select(slot)
                local placedSide = Basic.placeFrontTopOrBottom()

                if not placedSide then
                    error("no space to place shulker box")
                end

                local itemsForShulker, leftOver = sliceNumStacksFromItems(theItems, 26)
                theItems = leftOver
                fillShulker(itemsForShulker, placedSide)
                Elemental.dig(placedSide)

                local shulkerItem = Basic.getStack(slot, true)

                if not shulkerItem then
                    error("my shulker went poof :(")
                end

                fullShulkers[shulkerItem.nbt] = true
            end
        end
    end
end

---@param items table<string, integer>
function Squirtle.requireItems(items)
    local numStacks = itemsToStacks(items)

    -- [todo] assumes an empty inventory. also, doesn't consider current inventory state (e.g. we might already have some items,
    -- yet we still count stacks of total items required)
    if numStacks <= 16 then
        requireItemsNoShulker(items)
    else
        requireItemsUsingShulker(items)
    end
end

---@param target Vector
---@return boolean, string?
function Squirtle.moveToPoint(target)
    local delta = Vector.minus(target, Squirtle.locate())

    if delta.y > 0 then
        if not Squirtle.tryMove("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not Squirtle.tryMove("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        Squirtle.face(Cardinal.east)
        if not Squirtle.tryMove("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        Squirtle.face(Cardinal.west)
        if not Squirtle.tryMove("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        Squirtle.face(Cardinal.south)
        if not Squirtle.tryMove("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        Squirtle.face(Cardinal.north)
        if not Squirtle.tryMove("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param path Vector[]
---@return boolean, string?, integer?
local function walkPath(path)
    for i, next in ipairs(path) do
        local success, failedSide = Squirtle.moveToPoint(next)

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
        local position = Squirtle.locate(true)
        world = World.create(position.x, position.y, position.z)
    end

    local from, facing = Squirtle.orientate(true)

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
