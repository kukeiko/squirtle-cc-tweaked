local State = require "squirtle.state"
local getNative = require "squirtle.get-native"
local Elemental = require "squirtle.elemental"

---@class Basic:Elemental
local Basic = {}
setmetatable(Basic, {__index = Elemental})

---@param target integer
---@param current? integer
function Basic.face(target, current)
    if State.simulate then
        return nil
    end

    current = current or State.facing

    if not current then
        error("facing not available")
    end

    if (current + 2) % 4 == target then
        Elemental.turn("back")
    elseif (current + 1) % 4 == target then
        Elemental.turn("right")
    elseif (current - 1) % 4 == target then
        Elemental.turn("left")
    end

    return target
end

---@return string? direction
function Basic.placeFrontTopOrBottom()
    local directions = {"front", "top", "bottom"}

    for _, direction in pairs(directions) do
        if Elemental.place(direction) then
            return direction
        end
    end
end

---@param direction? string
---@return boolean, string?
function Basic.mine(direction)
    local success, message = Basic.tryMine(direction)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

---@param direction? string
---@return boolean, string?
function Basic.tryMine(direction)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    local native = getNative("dig", direction)
    local block = Elemental.probe(direction)

    if not block then
        return false
    end

    if not State.canBreak(block) then
        return false, string.format("not allowed to mine block %s", block.name)
    end

    local success, message = native()

    if not success and string.match(message, "tool") then
        error(string.format("failed to mine towards %s: %s", direction, message))
    end

    return success, message
end

---@param fuel integer
---@return boolean
function Basic.hasFuel(fuel)
    local level = Elemental.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

---@param limit? integer
---@return integer
function Basic.missingFuel(limit)
    local current = Elemental.getFuelLevel()

    if current == "unlimited" then
        return 0
    end

    return (limit or Elemental.getFuelLimit()) - current
end

---@param slot integer
---@return boolean
function Basic.selectIfNotEmpty(slot)
    if Elemental.getItemCount(slot) > 0 then
        return Elemental.select(slot)
    else
        return false
    end
end

---@param startAt? number
---@return integer
function Basic.selectEmpty(startAt)
    startAt = startAt or turtle.getSelectedSlot()

    for i = 0, Basic.size() - 1 do
        local slot = startAt + i

        if slot > Basic.size() then
            slot = slot - Basic.size()
        end

        if Basic.getItemCount(slot) == 0 then
            Basic.select(slot)

            return slot
        end
    end

    error("no empty slot available")
end

---@return integer
function Basic.selectFirstEmpty()
    return Basic.selectEmpty(1)
end

---@param startAt? number
function Basic.firstEmptySlot(startAt)
    -- [todo] this startAt logic works a bit differently to "Backpack.selectEmpty()" as it does not wrap around
    startAt = startAt or 1

    for slot = startAt, Basic.size() do
        if Basic.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return integer
function Basic.numEmptySlots()
    local numEmpty = 0

    for slot = 1, Basic.size() do
        if Basic.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function Basic.isFull()
    for slot = 1, Basic.size() do
        if Basic.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

---@return boolean
function Basic.isEmpty()
    for slot = 1, Basic.size() do
        if Basic.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

---@return ItemStack[]
function Basic.getStacks()
    local stacks = {}

    for slot = 1, Basic.size() do
        local item = Basic.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@param predicate string|function<boolean, ItemStack>
---@return integer
function Basic.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Basic.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@return table<string, integer>
function Basic.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Basic.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param name string
---@param exact? boolean
---@param startAtSlot? integer
---@return integer?
function Basic.find(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, Basic.size() do
        local item = Basic.getStack(slot)

        if item and exact and item.name == name then
            return slot
        elseif item and not exact and string.find(item.name, name) then
            return slot
        end
    end
end

---@param item string
---@param minCount? integer
---@return boolean
function Basic.has(item, minCount)
    if type(minCount) == "number" then
        return Basic.getItemStock(item) >= minCount
    else
        for slot = 1, Basic.size() do
            local stack = Basic.getStack(slot)

            if stack and stack.name == item then
                return true
            end
        end

        return false
    end
end

function Basic.condense()
    if State.simulate then
        return nil
    end

    for slot = Basic.size(), 1, -1 do
        local item = Basic.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = Basic.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    Basic.select(slot)
                    Basic.transferTo(targetSlot)

                    if Basic.getItemCount(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    Basic.select(slot)
                    Basic.transferTo(targetSlot)
                    break
                end
            end
        end
    end
end

return Basic
