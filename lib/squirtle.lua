local Utils = require "utils"
local World = require "geo.world"
local findPath = require "geo.find-path"
local Inventory = require "inventory.inventory"
local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"
local getStacks = require "inventory.get-stacks"
local toIoInventory = require "inventory.to-io-inventory"
local transferItem = require "inventory.transfer-item"
local transferItems = require "inventory.transfer-items"

---@class SquirtleV2SimulationResults
---@field steps integer
---@field placed table<string, integer>

local inventorySize = 16

local natives = {
    turn = {left = turtle.turnLeft, right = turtle.turnRight},
    move = {
        top = turtle.up,
        up = turtle.up,
        front = turtle.forward,
        forward = turtle.forward,
        bottom = turtle.down,
        down = turtle.down,
        back = turtle.back
    },
    dig = {
        top = turtle.digUp,
        up = turtle.digUp,
        front = turtle.dig,
        forward = turtle.dig,
        bottom = turtle.digDown,
        down = turtle.digDown
    },
    inspect = {
        top = turtle.inspectUp,
        up = turtle.inspectUp,
        front = turtle.inspect,
        forward = turtle.inspect,
        bottom = turtle.inspectDown,
        down = turtle.inspectDown
    },
    suck = {
        top = turtle.suckUp,
        up = turtle.suckUp,
        front = turtle.suck,
        forward = turtle.suck,
        bottom = turtle.suckDown,
        down = turtle.suckDown
    },
    place = {
        top = turtle.placeUp,
        up = turtle.placeUp,
        front = turtle.place,
        forward = turtle.place,
        bottom = turtle.placeDown,
        down = turtle.placeDown
    },
    drop = {
        top = turtle.dropUp,
        up = turtle.dropUp,
        front = turtle.drop,
        forward = turtle.drop,
        bottom = turtle.dropDown,
        down = turtle.dropDown
    }
}

local fuelItems = {
    -- ["minecraft:lava_bucket"] = 1000,
    ["minecraft:coal"] = 80,
    ["minecraft:charcoal"] = 80,
    ["minecraft:coal_block"] = 800
    -- ["minecraft:bamboo"] = 2
}

---@param fn string
---@param side string
---@return function
local function getNative(fn, side)
    local native = (natives[fn] or {})[side]

    if not native then
        error(string.format("%s does not support side %s", fn, side))
    end

    return native
end

---@param block Block
---@return boolean
local breakableSafeguard = function(block)
    return block.name ~= "minecraft:bedrock"
end

---@class Squirtle
---@field flipTurns boolean
---@field simulate boolean
---@field facing integer
---@field results SquirtleV2SimulationResults
---@field breakable? fun(block: Block) : boolean
local Squirtle = {
    flipTurns = false,
    simulate = false,
    results = {placed = {}, steps = 0},
    position = Vector.create(0, 0, 0),
    facing = Cardinal.south,
    inventorySize = 16
}

---@param block Block
---@return boolean
local function canBreak(block)
    return breakableSafeguard(block) and (Squirtle.breakable == nil or Squirtle.breakable(block))
end

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function Squirtle.setBreakable(predicate)
    local current = Squirtle.breakable

    local function restore()
        Squirtle.breakable = current
    end

    if type(predicate) == "table" then
        Squirtle.breakable = function(block)
            for _, item in pairs(predicate) do
                if block.name == item then
                    return true
                end
            end

            return false
        end
    else
        Squirtle.breakable = predicate
    end

    return restore
end

---@param side string
---@param steps? integer
---@return boolean
---@return integer
function Squirtle.tryWalk(side, steps)
    steps = steps or 1

    if Squirtle.simulate then
        -- "tryWalk()" doesn't simulate any steps because it is assumed that it is called only to move until an unbreakable block is hit,
        -- and since we're not simulating an actual world we can not really return a meaningful value of steps taken.
        return false, 0
    else
        local native = getNative("move", side)

        for step = 1, steps do
            if not native() then
                return false, step
            end
        end

        return true, steps
    end
end

---@param side? string
---@param steps? integer
---@return boolean, integer, string?
function Squirtle.tryMove(side, steps)
    side = side or "front"
    local native = natives.move[side]

    if not native then
        error(string.format("move() does not support side %s", side))
    end

    steps = steps or 1

    if Squirtle.simulate then
        Squirtle.results.steps = Squirtle.results.steps + 1
        return true, steps
    end

    if not Squirtle.hasFuel(steps) then
        Squirtle.refuel(steps)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(side, Squirtle.facing))

    for step = 1, steps do
        repeat
            local success = native()

            if not success then
                local actionSide = side

                if side == "back" then
                    actionSide = "front"
                    Squirtle.around()
                end

                while Squirtle.tryDig(actionSide) do
                end

                local block = Squirtle.inspect(actionSide)

                if block then
                    if side == "back" then
                        Squirtle.around()
                    end

                    return false, step - 1, string.format("blocked by %s", block.name)
                else
                    if side == "back" then
                        Squirtle.around()
                    end
                end
            end
        until success

        Squirtle.position = Vector.plus(Squirtle.position, delta)
    end

    return true, steps
end

---@param steps? integer
---@return boolean, integer, string?
function Squirtle.tryForward(steps)
    return Squirtle.tryMove("forward", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function Squirtle.tryUp(steps)
    return Squirtle.tryMove("up", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function Squirtle.tryDown(steps)
    return Squirtle.tryMove("down", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function Squirtle.tryBack(steps)
    return Squirtle.tryMove("back", steps)
end

---@param side? string
---@param steps? integer
function Squirtle.move(side, steps)
    if Squirtle.simulate then
        -- when simulating, only "move()" will simulate actual steps.
        steps = steps or 1
        Squirtle.results.steps = Squirtle.results.steps + 1

        return nil
    end

    local success, _, message = Squirtle.tryMove(side, steps)

    if not success then
        error(string.format("move(%s) failed: %s", side, message))
    end
end

---@param steps? integer
function Squirtle.forward(steps)
    Squirtle.move("forward", steps)
end

---@param steps? integer
function Squirtle.up(steps)
    Squirtle.move("up", steps)
end

---@param steps? integer
function Squirtle.down(steps)
    Squirtle.move("down", steps)
end

---@param steps? integer
function Squirtle.back(steps)
    Squirtle.move("back", steps)
end

---@param side? string
---@return boolean
function Squirtle.turn(side)
    if Squirtle.flipTurns then
        if side == "left" then
            side = "right"
        elseif side == "right" then
            side = "left"
        end
    end

    if Squirtle.simulate then
        return true
    end

    if side == "left" then
        turtle.turnLeft()
        Squirtle.facing = Cardinal.rotateLeft(Squirtle.facing)
        return true
    elseif side == "right" then
        turtle.turnRight()
        Squirtle.facing = Cardinal.rotateRight(Squirtle.facing)
        return true
    elseif side == "back" then
        local turnFn = natives.turn.left

        if math.random() < .5 then
            turnFn = natives.turn.right
        end
        turnFn()
        turnFn()
        Squirtle.facing = Cardinal.rotateLeft(Squirtle.facing, 2)

        return true
    elseif side == "front" then
        return true
    end

    error(string.format("turn() does not support side %s", side))
end

function Squirtle.left()
    Squirtle.turn("left")
end

function Squirtle.right()
    Squirtle.turn("right")
end

function Squirtle.around()
    Squirtle.turn("back")
end

---@param target integer
---@param current? integer
function Squirtle.face(target, current)
    current = current or Squirtle.facing

    if not current then
        error("facing not available")
    end

    if (current + 2) % 4 == target then
        Squirtle.turn("back")
    elseif (current + 1) % 4 == target then
        Squirtle.turn("right")
    elseif (current - 1) % 4 == target then
        Squirtle.turn("left")
    end

    return target
end

---@param refresh? boolean
function Squirtle.locate(refresh)
    if refresh then
        local x, y, z = gps.locate()

        if not x then
            error("no gps available")
        end

        Squirtle.position = Vector.create(x, y, z)
    end

    return Squirtle.position
end

---@param position Vector
local function stepOut(position)
    Squirtle.refuel(2)

    if not Squirtle.tryForward() then
        return false
    end

    local now = Squirtle.locate(true)
    Squirtle.facing = Cardinal.fromVector(Vector.minus(now, position))

    while not Squirtle.tryBack() do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position Vector
local function orientateSameLayer(position)
    if stepOut(position) then
        return true
    end

    Squirtle.left()

    if stepOut(position) then
        Squirtle.right()
        return true
    end

    Squirtle.left()

    if stepOut(position) then
        Squirtle.around()
        return true
    end

    Squirtle.left()

    if stepOut(position) then
        Squirtle.left()
        return true
    end

    return false
end

---@param refresh? boolean
---@return Vector position, integer facing
function Squirtle.orientate(refresh)
    local position = Squirtle.locate(refresh)
    local facing = Squirtle.facing

    if refresh or not facing then
        if not orientateSameLayer(position) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return Squirtle.position, Squirtle.facing
end

---@param side? string
---@return boolean, string?
function Squirtle.tryDig(side)
    if Squirtle.simulate then
        return true
    end

    side = side or "front"
    local native = natives.dig[side]

    if not native then
        error(string.format("dig() does not support side %s", side))
    end

    local block = Squirtle.inspect(side)

    if not block then
        return false
    end

    if not canBreak(block) then
        return false, string.format("not allowed to dig block %s", block.name)
    end

    local success, message = native()

    if not success and string.match(message, "tool") then
        error(string.format("dig(%s) failed: %s", side, message))
    end

    return success, message
end

---@param side? string
---@return boolean, string?
function Squirtle.dig(side)
    local success, message = Squirtle.tryDig(side)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

---@return boolean, string?
function Squirtle.digUp()
    return Squirtle.dig("up")
end

---@return boolean, string?
function Squirtle.digDown()
    return Squirtle.dig("down")
end

---@param block? string
---@return boolean
local function simulateTryPlace(block)
    if block then
        if not Squirtle.results.placed[block] then
            Squirtle.results.placed[block] = 0
        end

        Squirtle.results.placed[block] = Squirtle.results.placed[block] + 1
    end

    return true
end

---@param block? string
local function simulatePlace(block)
    simulateTryPlace(block)
end

---@param side? string
---@param block? string
function Squirtle.place(side, block)
    requireItem = requireItem or true

    if Squirtle.simulate then
        return simulatePlace(block)
    end

    if not Squirtle.tryPlace(side, block) then
        error("failed to place")
    end
end

---@param side? string
---@param block? string
---@return boolean
function Squirtle.tryPlace(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if Squirtle.simulate then
        return simulateTryPlace(block)
    end

    if block then
        while not Squirtle.select(block) do
            Squirtle.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while Squirtle.tryDig(side) do
    end

    return native()
end

---@param block? string
function Squirtle.placeFront(block)
    Squirtle.place("front", block)
end

---@param block? string
function Squirtle.placeUp(block)
    Squirtle.place("up", block)
end

---@param block? string
function Squirtle.placeDown(block)
    Squirtle.place("down", block)
end

---@return string? direction
function Squirtle.placeAnywhere()
    if turtle.place() then
        return "front"
    end

    if turtle.placeUp() then
        return "top"
    end

    if turtle.placeDown() then
        return "bottom"
    end
end

---@param side? string
---@param count? integer
---@return boolean, string?
function Squirtle.drop(side, count)
    side = side or "front"
    return getNative("drop", side)(count)
end

---@param side string
local function digSide(side)
    if side == "front" then
        turtle.dig()
    elseif side == "top" then
        turtle.digUp()
    elseif side == "bottom" then
        turtle.digDown()
    end
end

---@param alsoIgnoreSlot integer
---@return integer?
local function nextSlotThatIsNotShulker(alsoIgnoreSlot)
    for slot = 1, 16 do
        if alsoIgnoreSlot ~= slot then
            local item = turtle.getItemDetail(slot)

            if item.name ~= "minecraft:shulker_box" then
                return slot
            end
        end
    end
end

---@param shulker integer
---@param item string
---@return boolean
local function loadFromShulker(shulker, item)
    Squirtle.selectSlot(shulker)

    local placedSide = Squirtle.placeAnywhere()

    if not placedSide then
        return false
    end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = Inventory.getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            Squirtle.suckSlotFromChest(placedSide, stackSlot)
            local emptySlot = Squirtle.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                turtle.select(slotToPutIntoShulker)
                Squirtle.drop(placedSide)
                turtle.select(shulker)
            end

            -- [todo] cannot use Squirtle.dig() cause breaking shulkers might not be allowed
            digSide(placedSide)

            return true
        end
    end

    digSide(placedSide)

    return false
end

-- [todo] consider adding requireItems() logic here
-- [update] not every app would want that though, e.g. check out farmer app
---@param name string
---@param exact? boolean
---@return false|integer
local function selectItem(name, exact)
    local slot = Squirtle.find(name, exact)

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

    Squirtle.selectSlot(slot)

    return slot
end

---@param name string|integer
---@param exact? boolean
---@return false|integer
function Squirtle.select(name, exact)
    if type(name) == "string" then
        return selectItem(name, exact)
    else
        return turtle.select(name)
    end
end

---@param startAt? number
function Squirtle.selectEmpty(startAt)
    startAt = startAt or turtle.getSelectedSlot()

    for i = 0, inventorySize - 1 do
        local slot = startAt + i

        if slot > inventorySize then
            slot = slot - inventorySize
        end

        if turtle.getItemCount(slot) == 0 then
            return turtle.select(slot)
        end
    end

    return nil
end

---@param item string
---@param minCount? integer
---@return boolean
function Squirtle.has(item, minCount)
    if type(minCount) == "number" then
        return Squirtle.getItemStock(item) >= minCount
    else
        startAtSlot = startAtSlot or 1

        for slot = startAtSlot, Squirtle.size() do
            local item = Squirtle.getStack(slot)

            if item and item.name == item then
                return true
            end
        end

        return false
    end
end

-- [todo] assumes that everything stacks to 64
---@param items table<string, integer>
---@return integer
local function itemsToStacks(items)
    local numStacks = 0

    for _, numItems in pairs(items) do
        numStacks = numStacks + math.ceil(numItems / 64)
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
            local item = turtle.getItemDetail(slot)

            if item and item.name ~= "minecraft:shulker_box" then
                turtle.select(slot)
                Squirtle.drop(shulker)
            end
        end
    end
end

-- [todo] assumes that everything stacks to 64
---@param items table<string, integer>
---@param numStacks integer
---@return table<string, integer>,table<string, integer>
local function sliceNumStacksFromItems(items, numStacks)
    ---@type table<string, integer>
    local sliced = {}
    local remainingStacks = numStacks
    local leftOver = Utils.copy(items)

    for item, count in pairs(items) do
        local slicedCount = math.min(count, remainingStacks * 64)
        sliced[item] = slicedCount
        leftOver[item] = leftOver[item] - slicedCount

        if leftOver[item] == 0 then
            leftOver[item] = nil
        end

        remainingStacks = remainingStacks - math.ceil(slicedCount / 64)

        if remainingStacks == 0 then
            break
        end
    end

    return sliced, leftOver
end

-- [todo] assumes an empty inventory
---@param items table<string, integer>
function Squirtle.requireItems(items)
    local numStacks = itemsToStacks(items)

    if numStacks <= 16 then
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
    else
        -- shulkers have 27 slots, but we want to keep one slot empty per shulker
        -- so that suckSlotFromChest() doesn't have to temporarily load an item
        -- from the shulker into the turtle inventory
        local numShulkers = math.ceil(numStacks / 26)

        if numShulkers > 15 then
            error("required items would need more than 15 shulker boxes")
        end

        Squirtle.requireItems({["minecraft:shulker_box"] = numShulkers})

        local fullShulkers = {}
        local theItems = Utils.copy(items)

        for i = 1, numShulkers do
            for slot = 1, 16 do
                local item = turtle.getItemDetail(slot, true)

                if item and item.name == "minecraft:shulker_box" and not fullShulkers[item.nbt] then
                    turtle.select(slot)
                    local placedSide = Squirtle.placeAnywhere()

                    if not placedSide then
                        error("no space to place shulker box")
                    end

                    local itemsForShulker, leftOver = sliceNumStacksFromItems(theItems, 26)
                    theItems = leftOver
                    fillShulker(itemsForShulker, placedSide)
                    digSide(placedSide)
                    local shulkerItem = turtle.getItemDetail(slot, true)
                    fullShulkers[shulkerItem.nbt] = true
                end
            end
        end
    end
end

function Squirtle.condense()
    for slot = Squirtle.size(), 1, -1 do
        local item = Squirtle.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = Squirtle.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    Squirtle.selectSlot(slot)
                    Squirtle.transfer(targetSlot)

                    if Squirtle.numInSlot(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    Squirtle.selectSlot(slot)
                    Squirtle.transfer(targetSlot)
                    break
                end
            end
        end
    end
end

---@param side? string
---@param name? table|string
---@return Block? block
function Squirtle.inspect(side, name)
    side = side or "front"
    local native = natives.inspect[side]

    if not native then
        error(string.format("inspect() does not support side %s", side))
    end

    local success, block = native()

    if success then
        if name then
            if type(name) == "string" and block.name == name then
                return block
            elseif type(name) == "table" and Utils.indexOf(name, block.name) > 0 then
                return block
            else
                return nil
            end
        end

        return block
    else
        return nil
    end
end

---@param side? string
---@param limit? integer
---@return boolean, string?
function Squirtle.suck(side, limit)
    side = side or "front"
    local native = getNative("suck", side)

    return native(limit)
end

---@return integer
function Squirtle.size()
    return Squirtle.inventorySize
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function Squirtle.getStack(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end

---@param slot integer
---@param count? integer
function Squirtle.transfer(slot, count)
    return turtle.transferTo(slot, count)
end

---@return ItemStack[]
function Squirtle.getStacks()
    local stacks = {}

    for slot = 1, Squirtle.size() do
        local item = Squirtle.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@return boolean
function Squirtle.isEmpty()
    for slot = 1, Squirtle.size() do
        if Squirtle.numInSlot(slot) > 0 then
            return false
        end
    end

    return true
end

---@return table<string, integer>
function Squirtle.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Squirtle.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param predicate string|function<boolean, ItemStack>
function Squirtle.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Squirtle.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param slot integer
function Squirtle.selectSlot(slot)
    return turtle.select(slot)
end

---@param slot integer
---@return integer
function Squirtle.numInSlot(slot)
    return turtle.getItemCount(slot)
end

---@return boolean
function Squirtle.selectSlotIfNotEmpty(slot)
    if Squirtle.numInSlot(slot) > 0 then
        return Squirtle.selectSlot(slot)
    else
        return false
    end
end

---@param name string
---@param exact? boolean
---@param startAtSlot? integer
function Squirtle.find(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, Squirtle.size() do
        local item = Squirtle.getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and not exact and string.find(item.name, name) then
            return slot
        end
    end
end

---@return boolean
function Squirtle.isFull()
    for slot = 1, Squirtle.size() do
        if Squirtle.numInSlot(slot) == 0 then
            return false
        end
    end

    return true
end

---@param startAt? number
function Squirtle.firstEmptySlot(startAt)
    startAt = startAt or 1

    for slot = startAt, Squirtle.size() do
        if Squirtle.numInSlot(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return boolean|integer
function Squirtle.selectFirstEmptySlot()
    local slot = Squirtle.firstEmptySlot()

    if not slot then
        return false
    end

    Squirtle.selectSlot(slot)

    return slot
end

---@param side string
---@return boolean success if everything could be dumped
function Squirtle.dump(side)
    local items = Squirtle.getStacks()

    for slot in pairs(items) do
        Squirtle.selectSlot(slot)
        Squirtle.drop(side)
    end

    return Squirtle.isEmpty()
end

---@param fuel integer
function Squirtle.hasFuel(fuel)
    local level = turtle.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

---@param limit? integer
---@return integer
function Squirtle.missingFuel(limit)
    local current = turtle.getFuelLevel()

    if current == "unlimited" then
        return 0
    end

    return (limit or turtle.getFuelLimit()) - current
end

---@param quantity? integer
---@return boolean
function Squirtle.refuelSlot(quantity)
    return turtle.refuel(quantity)
end

---@return integer
function Squirtle.getFuelLevel()
    return turtle.getFuelLevel()
end

---@return integer
function Squirtle.getFuelLimit()
    return turtle.getFuelLimit()
end

---@param item string
function Squirtle.isFuel(item)
    return fuelItems[item] ~= nil
end

---@param item string
function Squirtle.getRefuelAmount(item)
    return fuelItems[item] or 0
end

---@param stack table
function Squirtle.getStackRefuelAmount(stack)
    return Squirtle.getRefuelAmount(stack.name) * stack.count
end

---@param stacks ItemStack[]
---@param fuel number
---@param allowedOverFlow? number
---@return ItemStack[] fuelStacks, number openFuel
function Squirtle.pickStacks(stacks, fuel, allowedOverFlow)
    allowedOverFlow = math.max(allowedOverFlow or 1000, 0)
    local pickedStacks = {}
    local openFuel = fuel

    -- [todo] try to order stacks based on type of item
    -- for example, we may want to start with the smallest ones to minimize potential overflow
    for slot, stack in pairs(stacks) do
        if Squirtle.isFuel(stack.name) then
            local stackRefuelAmount = Squirtle.getStackRefuelAmount(stack)

            if stackRefuelAmount <= openFuel then
                pickedStacks[slot] = stack
                openFuel = openFuel - stackRefuelAmount
            else
                -- [todo] can be shortened
                -- actually, im not even sure we need the option to provide an allowed overflow
                local itemRefuelAmount = Squirtle.getRefuelAmount(stack.name)
                local numRequiredItems = math.floor(openFuel / itemRefuelAmount)
                local numItemsToPick = numRequiredItems

                if allowedOverFlow > 0 and ((numItemsToPick + 1) * itemRefuelAmount) - openFuel <= allowedOverFlow then
                    numItemsToPick = numItemsToPick + 1
                end
                -- local numRequiredItems = math.ceil(openFuel / itemRefuelAmount)

                -- if (numRequiredItems * itemRefuelAmount) - openFuel <= allowedOverFlow then
                if numItemsToPick > 0 then
                    pickedStacks[slot] = {name = stack.name, count = numItemsToPick}
                    openFuel = openFuel - stackRefuelAmount
                end
            end

            if openFuel <= 0 then
                break
            end
        end
    end

    return pickedStacks, openFuel
end

local bucket = "minecraft:bucket"

---@param fuel? integer
local function refuelFromBackpack(fuel)
    fuel = fuel or Squirtle.getMissingFuel()
    local fuelStacks = Squirtle.pickStacks(Squirtle.getStacks(), fuel)
    local emptyBucketSlot = Squirtle.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        Squirtle.selectSlot(slot)
        Squirtle.refuel(stack.count)

        local remaining = Squirtle.getStack(slot)

        if remaining and remaining.name == bucket then
            if (emptyBucketSlot == nil) or (not Squirtle.transfer(emptyBucketSlot)) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or Squirtle.getMissingFuel()

    if fuel > turtle.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - turtle.getFuelLimit()))
    end

    local _, y = term.getCursorPos()

    while Squirtle.getFuelLevel() < fuel do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - Squirtle.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function Squirtle.refuel(fuel)
    if Squirtle.hasFuel(fuel) then
        return true
    end

    refuelFromBackpack(fuel)

    if Squirtle.getFuelLevel() < fuel then
        refuelWithHelpFromPlayer(fuel)
    end
end

local function firstEmptySlot(table, size)
    for index = 1, size do
        if table[index] == nil then
            return index
        end
    end
end

local natives = {
    top = turtle.suckUp,
    up = turtle.suckUp,
    front = turtle.suck,
    forward = turtle.suck,
    bottom = turtle.suckDown,
    down = turtle.suckDown
}

---@param side? string
---@param limit? integer
---@return boolean,string?
local function suck(side, limit)
    side = side or "front"
    local handler = natives[side]

    if not handler then
        error(string.format("suck() does not support side %s", side))
    end

    return handler(limit)
end

---@param side string
---@param slot integer
---@param limit? integer
---@return any
function Squirtle.suckSlotFromChest(side, slot, limit)
    if slot == 1 then
        return Squirtle.suck(side, limit)
    end

    local items = Inventory.getStacks(side)

    if items[1] ~= nil then
        local firstEmptySlot = firstEmptySlot(items, Inventory.getSize(side))

        if not firstEmptySlot and Squirtle.isFull() then
            error("container full. turtle also full, so no temporary unloading possible.")
        elseif not firstEmptySlot then
            if limit ~= nil and limit ~= items[slot].count then
                -- [todo] we're not gonna have a slot free in the container
                error("not yet implemented: container would still be full even after moving slot")
            end

            print("temporarily load first container slot into turtle...")
            local initialSlot = turtle.getSelectedSlot()
            Squirtle.selectFirstEmptySlot()
            Squirtle.suck(side)
            Inventory.pushItems(side, side, slot, limit, 1)
            -- [todo] if we want to be super strict, we would have to move the
            -- item we just sucked in back to the first slot after sucking the requested item
            Squirtle.drop(side)
            print("pushing back temporarily loaded item")
            turtle.select(initialSlot)
        else
            Inventory.pushItems(side, side, 1, nil, firstEmptySlot)
            Inventory.pushItems(side, side, slot, limit, 1)
        end
    else
        Inventory.pushItems(side, side, slot, limit, 1)
    end

    return suck(side, limit)
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
        Squirtle.refuel(distance)
        local success, failedSide = walkPath(path)

        if success then
            return true
        elseif failedSide then
            from, facing = Squirtle.orientate()
            local block = Squirtle.inspect(failedSide)
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))

            if block and breakable(block) then
                Squirtle.dig(failedSide)
            elseif block then
                World.setBlock(world, scannedLocation)
            else
                error("could not move, not sure why")
            end
        end
    end
end

---@param from string
---@param to string
---@return table<string, integer> transferredStock
function Squirtle.pullInput(from, to)
    local maxStock = Inventory.getInputStock(from)
    local currentStock = Inventory.getStock(to)
    -- [todo] i have the same name "stock" for two different data structures :/ (table<string, int> and table<string, ItemStack>)
    ---@type table<string, integer>
    local missingStock = {}

    for item, stock in pairs(maxStock) do
        missingStock[item] = stock.maxCount - ((currentStock[item] or {}).count or 0)
    end

    ---@type table<string, integer>
    local transferredStock = {}

    for slot, stack in pairs(Inventory.getInputStacks(from)) do
        local stock = missingStock[stack.name]

        if stock ~= nil and stock > 0 then
            local limit = math.min(stack.count - 1, stock)
            local transferred = Inventory.pullItems(to, from, slot, limit)
            missingStock[stack.name] = stock - transferred

            if transferred > 0 then
                transferredStock[stack.name] = (transferredStock[stack.name] or 0) + transferred
            end
        end
    end

    return transferredStock
end

-- [note] copied from io-chestcart
---@param from InputOutputInventory
---@param to Inventory
---@param transferredOutput? table<string, integer>
---@param rate? integer
---@return table<string, integer> transferred
function Squirtle.pullInput_v2(from, to, transferredOutput, rate)
    transferredOutput = transferredOutput or {}
    ---@type table<string, integer>
    local transferrable = {}

    for item, stock in pairs(from.input.stock) do
        local maxStock = stock.maxCount

        if from.output.stock[item] then
            maxStock = maxStock + from.output.stock[item].maxCount
        end

        maxStock = maxStock - (transferredOutput[item] or 0)

        local toStock = to.stock[item]

        if toStock then
            maxStock = maxStock - toStock.count
        end

        transferrable[item] = math.min(stock.count, maxStock)
    end

    return Inventory.transferItems(from.input, to, transferrable, rate, true)
end

-- [todo] keepStock is not used yet anywhere; but i want to keep it because it should (imo)
-- be used @ lumberjack to push birch-saplings, but make sure to always keep at least 32
---@param from string
---@param to string
---@param keepStock? table<string, integer>
---@return boolean, table<string, integer>
function Squirtle.pushOutput(from, to, keepStock)
    keepStock = keepStock or {}

    ---@type  table<string, integer>
    local transferredStock = {}
    local fromStacks = Inventory.getStacks(from)
    local fromInventory = Inventory.create(from, fromStacks)
    local toInventory = toIoInventory(to)
    local transferredAll = true

    for item, stock in pairs(toInventory.output.stock) do
        local fromStock = fromInventory.stock[item]

        if fromStock then
            local pushable = math.max(fromStock.count - (keepStock[item] or 0), 0)
            local open = stock.maxCount - stock.count
            local transfer = math.min(open, pushable)

            while stock.count < stock.maxCount do
                local transferred = Inventory.transferItem(fromInventory, toInventory.output, item, transfer, 16)
                transferredStock[item] = (transferredStock[item] or 0) + transferred

                if transferred ~= transfer then
                    -- assuming chest is full or its state changed from an external source, in which case we just ignore it
                    break
                end
            end

            if fromStock.count - (keepStock[item] or 0) > 0 then
                transferredAll = false
            end
        end
    end

    return transferredAll, transferredStock
end

---@param checkEarlyExit? fun() : boolean
---@return boolean
function Squirtle.navigateTunnel(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and turtle.up() then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and turtle.down() then
            strategy = "down"
            forbidden = "up"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and forbidden ~= "back" and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while turtle.forward() do
            end
        elseif strategy == "up" then
            while turtle.up() do
            end
        elseif strategy == "down" then
            while turtle.down() do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end

return Squirtle
