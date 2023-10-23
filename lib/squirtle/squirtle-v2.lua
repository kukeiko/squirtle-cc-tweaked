local Utils = require "utils"
local Chest = require "world.chest"
local World = require "geo.world"
local findPath = require "geo.find-path"
local Inventory = require "inventory.inventory"
local Cardinal = require "elements.cardinal"
local Vector = require "elements.vector"
local subtractStock = require "world.chest.subtract-stock"
local getStacks = require "inventory.get-stacks"
local toIoInventory = require "inventory.to-io-inventory"
local transferItem = require "inventory.transfer-item"

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

---@class SquirtleV2
---@field flipTurns boolean
---@field simulate boolean
---@field facing integer
---@field results SquirtleV2SimulationResults
---@field breakable? fun(block: Block) : boolean
local SquirtleV2 = {
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
    return breakableSafeguard(block) and (SquirtleV2.breakable == nil or SquirtleV2.breakable(block))
end

---@param predicate? (fun(block: Block) : boolean) | string[]
---@return fun() : nil
function SquirtleV2.setBreakable(predicate)
    local current = SquirtleV2.breakable

    local function restore()
        SquirtleV2.breakable = current
    end

    if type(predicate) == "table" then
        SquirtleV2.breakable = function(block)
            for _, item in pairs(predicate) do
                if block.name == item then
                    return true
                end
            end

            return false
        end
    else
        SquirtleV2.breakable = predicate
    end

    return restore
end

---@param side string
---@param steps? integer
---@return boolean
---@return integer
function SquirtleV2.tryWalk(side, steps)
    steps = steps or 1

    if SquirtleV2.simulate then
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
function SquirtleV2.tryMove(side, steps)
    side = side or "front"
    local native = natives.move[side]

    if not native then
        error(string.format("move() does not support side %s", side))
    end

    steps = steps or 1

    if SquirtleV2.simulate then
        SquirtleV2.results.steps = SquirtleV2.results.steps + 1
        return true, steps
    end

    if not SquirtleV2.hasFuel(steps) then
        SquirtleV2.refuel(steps)
    end

    local delta = Cardinal.toVector(Cardinal.fromSide(side, SquirtleV2.facing))

    for step = 1, steps do
        repeat
            local success = native()

            if not success then
                local actionSide = side

                if side == "back" then
                    actionSide = "front"
                    SquirtleV2.around()
                end

                while SquirtleV2.tryDig(actionSide) do
                end

                local block = SquirtleV2.inspect(actionSide)

                if block then
                    if side == "back" then
                        SquirtleV2.around()
                    end

                    return false, step - 1, string.format("blocked by %s", block.name)
                else
                    if side == "back" then
                        SquirtleV2.around()
                    end
                end
            end
        until success

        SquirtleV2.position = Vector.plus(SquirtleV2.position, delta)
    end

    return true, steps
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryForward(steps)
    return SquirtleV2.tryMove("forward", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryUp(steps)
    return SquirtleV2.tryMove("up", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryDown(steps)
    return SquirtleV2.tryMove("down", steps)
end

---@param steps? integer
---@return boolean, integer, string?
function SquirtleV2.tryBack(steps)
    return SquirtleV2.tryMove("back", steps)
end

---@param side? string
---@param steps? integer
function SquirtleV2.move(side, steps)
    if SquirtleV2.simulate then
        -- when simulating, only "move()" will simulate actual steps.
        steps = steps or 1
        SquirtleV2.results.steps = SquirtleV2.results.steps + 1

        return nil
    end

    local success, _, message = SquirtleV2.tryMove(side, steps)

    if not success then
        error(string.format("move(%s) failed: %s", side, message))
    end
end

---@param steps? integer
function SquirtleV2.forward(steps)
    SquirtleV2.move("forward", steps)
end

---@param steps? integer
function SquirtleV2.up(steps)
    SquirtleV2.move("up", steps)
end

---@param steps? integer
function SquirtleV2.down(steps)
    SquirtleV2.move("down", steps)
end

---@param steps? integer
function SquirtleV2.back(steps)
    SquirtleV2.move("back", steps)
end

---@param side? string
---@return boolean
function SquirtleV2.turn(side)
    if SquirtleV2.flipTurns then
        if side == "left" then
            side = "right"
        elseif side == "right" then
            side = "left"
        end
    end

    if SquirtleV2.simulate then
        return true
    end

    if side == "left" then
        turtle.turnLeft()
        SquirtleV2.facing = Cardinal.rotateLeft(SquirtleV2.facing)
        return true
    elseif side == "right" then
        turtle.turnRight()
        SquirtleV2.facing = Cardinal.rotateRight(SquirtleV2.facing)
        return true
    elseif side == "back" then
        local turnFn = natives.turn.left

        if math.random() < .5 then
            turnFn = natives.turn.right
        end
        turnFn()
        turnFn()
        SquirtleV2.facing = Cardinal.rotateLeft(SquirtleV2.facing, 2)

        return true
    elseif side == "front" then
        return true
    end

    error(string.format("turn() does not support side %s", side))
end

function SquirtleV2.left()
    SquirtleV2.turn("left")
end

function SquirtleV2.right()
    SquirtleV2.turn("right")
end

function SquirtleV2.around()
    SquirtleV2.turn("back")
end

---@param target integer
---@param current? integer
function SquirtleV2.face(target, current)
    current = current or SquirtleV2.facing

    if not current then
        error("facing not available")
    end

    if (current + 2) % 4 == target then
        SquirtleV2.turn("back")
    elseif (current + 1) % 4 == target then
        SquirtleV2.turn("right")
    elseif (current - 1) % 4 == target then
        SquirtleV2.turn("left")
    end

    return target
end

---@param refresh? boolean
function SquirtleV2.locate(refresh)
    if refresh then
        local x, y, z = gps.locate()

        if not x then
            error("no gps available")
        end

        SquirtleV2.position = Vector.create(x, y, z)
    end

    return SquirtleV2.position
end

---@param position Vector
local function stepOut(position)
    SquirtleV2.refuel(2)

    if not SquirtleV2.tryForward() then
        return false
    end

    local now = SquirtleV2.locate(true)
    SquirtleV2.facing = Cardinal.fromVector(Vector.minus(now, position))

    while not SquirtleV2.tryBack() do
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

    SquirtleV2.left()

    if stepOut(position) then
        SquirtleV2.right()
        return true
    end

    SquirtleV2.left()

    if stepOut(position) then
        SquirtleV2.around()
        return true
    end

    SquirtleV2.left()

    if stepOut(position) then
        SquirtleV2.left()
        return true
    end

    return false
end

---@param refresh? boolean
---@return Vector position, integer facing
function SquirtleV2.orientate(refresh)
    local position = SquirtleV2.locate(refresh)
    local facing = SquirtleV2.facing

    if refresh or not facing then
        if not orientateSameLayer(position) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return SquirtleV2.position, SquirtleV2.facing
end

---@param side? string
---@return boolean, string?
function SquirtleV2.tryDig(side)
    if SquirtleV2.simulate then
        return true
    end

    side = side or "front"
    local native = natives.dig[side]

    if not native then
        error(string.format("dig() does not support side %s", side))
    end

    local block = SquirtleV2.inspect(side)

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
function SquirtleV2.dig(side)
    local success, message = SquirtleV2.tryDig(side)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

---@return boolean, string?
function SquirtleV2.digUp()
    return SquirtleV2.dig("up")
end

---@return boolean, string?
function SquirtleV2.digDown()
    return SquirtleV2.dig("down")
end

---@param block? string
---@return boolean
local function simulateTryPlace(block)
    if block then
        if not SquirtleV2.results.placed[block] then
            SquirtleV2.results.placed[block] = 0
        end

        SquirtleV2.results.placed[block] = SquirtleV2.results.placed[block] + 1
    end

    return true
end

---@param block? string
local function simulatePlace(block)
    simulateTryPlace(block)
end

---@param side? string
---@param block? string
function SquirtleV2.place(side, block)
    requireItem = requireItem or true

    if SquirtleV2.simulate then
        return simulatePlace(block)
    end

    if not SquirtleV2.tryPlace(side, block) then
        error("failed to place")
    end
end

---@param side? string
---@param block? string
---@return boolean
function SquirtleV2.tryPlace(side, block)
    side = side or "front"
    local native = getNative("place", side)

    if SquirtleV2.simulate then
        return simulateTryPlace(block)
    end

    if block then
        while not SquirtleV2.select(block) do
            SquirtleV2.requireItems({[block] = 1})
        end
    end

    if native() then
        return true
    end

    while SquirtleV2.tryDig(side) do
    end

    return native()
end

---@param block? string
function SquirtleV2.placeFront(block)
    SquirtleV2.place("front", block)
end

---@param block? string
function SquirtleV2.placeUp(block)
    SquirtleV2.place("up", block)
end

---@param block? string
function SquirtleV2.placeDown(block)
    SquirtleV2.place("down", block)
end

---@return string? direction
function SquirtleV2.placeAnywhere()
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
function SquirtleV2.drop(side, count)
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
    SquirtleV2.selectSlot(shulker)

    local placedSide = SquirtleV2.placeAnywhere()

    if not placedSide then
        return false
    end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local stacks = Inventory.getStacks(placedSide)

    for stackSlot, stack in pairs(stacks) do
        if stack.name == item then
            SquirtleV2.suckSlotFromChest(placedSide, stackSlot)
            local emptySlot = SquirtleV2.firstEmptySlot()

            if not emptySlot then
                local slotToPutIntoShulker = nextSlotThatIsNotShulker(shulker)

                if not slotToPutIntoShulker then
                    error("i seem to be full with shulkers")
                end

                turtle.select(slotToPutIntoShulker)
                SquirtleV2.drop(placedSide)
                turtle.select(shulker)
            end

            -- [todo] cannot use SquirtleV2.dig() cause breaking shulkers might not be allowed
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
    local slot = SquirtleV2.find(name, exact)

    if not slot then
        local nextShulkerSlot = 1

        while true do
            local shulker = SquirtleV2.find("minecraft:shulker_box", true, nextShulkerSlot)

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

    SquirtleV2.selectSlot(slot)

    return slot
end

---@param name string|integer
---@param exact? boolean
---@return false|integer
function SquirtleV2.select(name, exact)
    if type(name) == "string" then
        return selectItem(name, exact)
    else
        return turtle.select(name)
    end
end

---@param startAt? number
function SquirtleV2.selectEmpty(startAt)
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
function SquirtleV2.has(item, minCount)
    if type(minCount) == "number" then
        return SquirtleV2.getItemStock(item) >= minCount
    else
        startAtSlot = startAtSlot or 1

        for slot = startAtSlot, SquirtleV2.size() do
            local item = SquirtleV2.getStack(slot)

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
    local stock = SquirtleV2.getStock()

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
                SquirtleV2.drop(shulker)
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
function SquirtleV2.requireItems(items)
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

        SquirtleV2.requireItems({["minecraft:shulker_box"] = numShulkers})

        local fullShulkers = {}
        local theItems = Utils.copy(items)

        for i = 1, numShulkers do
            for slot = 1, 16 do
                local item = turtle.getItemDetail(slot, true)

                if item and item.name == "minecraft:shulker_box" and not fullShulkers[item.nbt] then
                    turtle.select(slot)
                    local placedSide = SquirtleV2.placeAnywhere()

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

function SquirtleV2.condense()
    for slot = SquirtleV2.size(), 1, -1 do
        local item = SquirtleV2.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = SquirtleV2.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    SquirtleV2.selectSlot(slot)
                    SquirtleV2.transfer(targetSlot)

                    if SquirtleV2.numInSlot(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    SquirtleV2.selectSlot(slot)
                    SquirtleV2.transfer(targetSlot)
                    break
                end
            end
        end
    end
end

---@param side? string
---@param name? table|string
---@return Block? block
function SquirtleV2.inspect(side, name)
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
function SquirtleV2.suck(side, limit)
    side = side or "front"
    local native = getNative("suck", side)

    return native(limit)
end

---@return integer
function SquirtleV2.size()
    return SquirtleV2.inventorySize
end

---@param slot integer
---@param detailed? boolean
---@return ItemStack?
function SquirtleV2.getStack(slot, detailed)
    return turtle.getItemDetail(slot, detailed)
end

---@param slot integer
---@param count? integer
function SquirtleV2.transfer(slot, count)
    return turtle.transferTo(slot, count)
end

---@return ItemStack[]
function SquirtleV2.getStacks()
    local stacks = {}

    for slot = 1, SquirtleV2.size() do
        local item = SquirtleV2.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@return boolean
function SquirtleV2.isEmpty()
    for slot = 1, SquirtleV2.size() do
        if SquirtleV2.numInSlot(slot) > 0 then
            return false
        end
    end

    return true
end

---@return table<string, integer>
function SquirtleV2.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(SquirtleV2.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param predicate string|function<boolean, ItemStack>
function SquirtleV2.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(SquirtleV2.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@param slot integer
function SquirtleV2.selectSlot(slot)
    return turtle.select(slot)
end

---@param slot integer
---@return integer
function SquirtleV2.numInSlot(slot)
    return turtle.getItemCount(slot)
end

---@return boolean
function SquirtleV2.selectSlotIfNotEmpty(slot)
    if SquirtleV2.numInSlot(slot) > 0 then
        return SquirtleV2.selectSlot(slot)
    else
        return false
    end
end

---@param name string
---@param exact? boolean
---@param startAtSlot? integer
function SquirtleV2.find(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, SquirtleV2.size() do
        local item = SquirtleV2.getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and not exact and string.find(item.name, name) then
            return slot
        end
    end
end

---@return boolean
function SquirtleV2.isFull()
    for slot = 1, SquirtleV2.size() do
        if SquirtleV2.numInSlot(slot) == 0 then
            return false
        end
    end

    return true
end

---@param startAt? number
function SquirtleV2.firstEmptySlot(startAt)
    startAt = startAt or 1

    for slot = startAt, SquirtleV2.size() do
        if SquirtleV2.numInSlot(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return boolean|integer
function SquirtleV2.selectFirstEmptySlot()
    local slot = SquirtleV2.firstEmptySlot()

    if not slot then
        return false
    end

    SquirtleV2.selectSlot(slot)

    return slot
end

---@param side string
---@return boolean success if everything could be dumped
function SquirtleV2.dump(side)
    local items = SquirtleV2.getStacks()

    for slot in pairs(items) do
        SquirtleV2.selectSlot(slot)
        SquirtleV2.drop(side)
    end

    return SquirtleV2.isEmpty()
end

---@param fuel integer
function SquirtleV2.hasFuel(fuel)
    local level = turtle.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

---@param limit? integer
---@return integer
function SquirtleV2.missingFuel(limit)
    local current = turtle.getFuelLevel()

    if current == "unlimited" then
        return 0
    end

    return (limit or turtle.getFuelLimit()) - current
end

---@param quantity? integer
---@return boolean
function SquirtleV2.refuelSlot(quantity)
    return turtle.refuel(quantity)
end

---@return integer
function SquirtleV2.getFuelLevel()
    return turtle.getFuelLevel()
end

---@return integer
function SquirtleV2.getFuelLimit()
    return turtle.getFuelLimit()
end

---@param item string
function SquirtleV2.isFuel(item)
    return fuelItems[item] ~= nil
end

---@param item string
function SquirtleV2.getRefuelAmount(item)
    return fuelItems[item] or 0
end

---@param stack table
function SquirtleV2.getStackRefuelAmount(stack)
    return SquirtleV2.getRefuelAmount(stack.name) * stack.count
end

---@param stacks ItemStack[]
---@param fuel number
---@param allowedOverFlow? number
---@return ItemStack[] fuelStacks, number openFuel
function SquirtleV2.pickStacks(stacks, fuel, allowedOverFlow)
    allowedOverFlow = math.max(allowedOverFlow or 1000, 0)
    local pickedStacks = {}
    local openFuel = fuel

    -- [todo] try to order stacks based on type of item
    -- for example, we may want to start with the smallest ones to minimize potential overflow
    for slot, stack in pairs(stacks) do
        if SquirtleV2.isFuel(stack.name) then
            local stackRefuelAmount = SquirtleV2.getStackRefuelAmount(stack)

            if stackRefuelAmount <= openFuel then
                pickedStacks[slot] = stack
                openFuel = openFuel - stackRefuelAmount
            else
                -- [todo] can be shortened
                -- actually, im not even sure we need the option to provide an allowed overflow
                local itemRefuelAmount = SquirtleV2.getRefuelAmount(stack.name)
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
    fuel = fuel or SquirtleV2.getMissingFuel()
    local fuelStacks = SquirtleV2.pickStacks(SquirtleV2.getStacks(), fuel)
    local emptyBucketSlot = SquirtleV2.find(bucket)

    for slot, stack in pairs(fuelStacks) do
        SquirtleV2.selectSlot(slot)
        SquirtleV2.refuel(stack.count)

        local remaining = SquirtleV2.getStack(slot)

        if remaining and remaining.name == bucket then
            if (emptyBucketSlot == nil) or (not SquirtleV2.transfer(emptyBucketSlot)) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param fuel? integer
local function refuelWithHelpFromPlayer(fuel)
    fuel = fuel or SquirtleV2.getMissingFuel()

    if fuel > turtle.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - turtle.getFuelLimit()))
    end

    local _, y = term.getCursorPos()

    while SquirtleV2.getFuelLevel() < fuel do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - SquirtleV2.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(openFuel)
    end
end

---@param fuel integer
function SquirtleV2.refuel(fuel)
    if SquirtleV2.hasFuel(fuel) then
        return true
    end

    refuelFromBackpack(fuel)

    if SquirtleV2.getFuelLevel() < fuel then
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
function SquirtleV2.suckSlotFromChest(side, slot, limit)
    if slot == 1 then
        return SquirtleV2.suck(side, limit)
    end

    local items = Inventory.getStacks(side)

    if items[1] ~= nil then
        local firstEmptySlot = firstEmptySlot(items, Inventory.getSize(side))

        if not firstEmptySlot and SquirtleV2.isFull() then
            error("container full. turtle also full, so no temporary unloading possible.")
        elseif not firstEmptySlot then
            if limit ~= nil and limit ~= items[slot].count then
                -- [todo] we're not gonna have a slot free in the container
                error("not yet implemented: container would still be full even after moving slot")
            end

            print("temporarily load first container slot into turtle...")
            local initialSlot = turtle.getSelectedSlot()
            SquirtleV2.selectFirstEmptySlot()
            SquirtleV2.suck(side)
            Chest.pushItems(side, side, slot, limit, 1)
            -- [todo] if we want to be super strict, we would have to move the
            -- item we just sucked in back to the first slot after sucking the requested item
            SquirtleV2.drop(side)
            print("pushing back temporarily loaded item")
            turtle.select(initialSlot)
        else
            Chest.pushItems(side, side, 1, nil, firstEmptySlot)
            Chest.pushItems(side, side, slot, limit, 1)
        end
    else
        Chest.pushItems(side, side, slot, limit, 1)
    end

    return suck(side, limit)
end

---@param target Vector
---@return boolean, string?
function SquirtleV2.moveToPoint(target)
    local delta = Vector.minus(target, SquirtleV2.locate())

    if delta.y > 0 then
        if not SquirtleV2.tryMove("top", delta.y) then
            return false, "top"
        end
    elseif delta.y < 0 then
        if not SquirtleV2.tryMove("bottom", -delta.y) then
            return false, "bottom"
        end
    end

    if delta.x > 0 then
        SquirtleV2.face(Cardinal.east)
        if not SquirtleV2.tryMove("front", delta.x) then
            return false, "front"
        end
    elseif delta.x < 0 then
        SquirtleV2.face(Cardinal.west)
        if not SquirtleV2.tryMove("front", -delta.x) then
            return false, "front"
        end
    end

    if delta.z > 0 then
        SquirtleV2.face(Cardinal.south)
        if not SquirtleV2.tryMove("front", delta.z) then
            return false, "front"
        end
    elseif delta.z < 0 then
        SquirtleV2.face(Cardinal.north)
        if not SquirtleV2.tryMove("front", -delta.z) then
            return false, "front"
        end
    end

    return true
end

---@param path Vector[]
---@return boolean, string?, integer?
local function walkPath(path)
    for i, next in ipairs(path) do
        local success, failedSide = SquirtleV2.moveToPoint(next)

        if not success then
            return false, failedSide, i
        end
    end

    return true
end

---@param to Vector
---@param world? World
---@param breakable? function
function SquirtleV2.navigate(to, world, breakable)
    breakable = breakable or function(...)
        return false
    end

    if not world then
        local position = SquirtleV2.locate(true)
        world = World.create(position.x, position.y, position.z)
    end

    local from, facing = SquirtleV2.orientate(true)

    while true do
        local path, msg = findPath(from, to, facing, world)

        if not path then
            return false, msg
        end

        local distance = Vector.manhattan(from, to)
        SquirtleV2.refuel(distance)
        local success, failedSide = walkPath(path)

        if success then
            return true
        elseif failedSide then
            from, facing = SquirtleV2.orientate()
            local block = SquirtleV2.inspect(failedSide)
            local scannedLocation = Vector.plus(from, Cardinal.toVector(Cardinal.fromSide(failedSide, facing)))

            if block and breakable(block) then
                SquirtleV2.dig(failedSide)
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
---@param maxStock? table<string, integer>
---@return table<string, integer> transferredStock
function SquirtleV2.pullInput(from, to, maxStock)
    maxStock = maxStock or Chest.getInputMaxStock(from)
    -- local maxStock = Chest.getInputOutputMaxStock(from)
    local currentStock = Chest.getStock(to)
    local missingStock = subtractStock(maxStock, currentStock)
    ---@type table<string, integer>
    local transferredStock = {}

    for slot, stack in pairs(Chest.getInputStacks(from)) do
        local stock = missingStock[stack.name]

        if stock ~= nil and stock > 0 then
            local limit = math.min(stack.count - 1, stock)
            local transferred = Chest.pullItems(to, from, slot, limit)
            missingStock[stack.name] = stock - transferred

            if transferred > 0 then
                transferredStock[stack.name] = (transferredStock[stack.name] or 0) + transferred
            end
        end
    end

    return transferredStock
end

-- [todo] keepStock is not used yet anywhere; but i want to keep it because it should (imo)
-- be used @ lumberjack to push birch-saplings, but make sure to always keep at least 32
---@param from string
---@param to string
---@param keepStock? table<string, integer>
---@return boolean, table<string, integer>
function SquirtleV2.pushOutput(from, to, keepStock)
    keepStock = keepStock or {}

    ---@type  table<string, integer>
    local transferredStock = {}
    local fromStacks = getStacks(from)
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
                local transferred = transferItem(fromInventory, toInventory.output, item, transfer, 16)
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
function SquirtleV2.navigateTunnel(checkEarlyExit)
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

return SquirtleV2
