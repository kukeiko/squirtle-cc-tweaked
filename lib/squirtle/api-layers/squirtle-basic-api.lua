local State = require "lib.squirtle.state"
local getNative = require "lib.squirtle.get-native"
local SquirtleElementalApi = require "lib.squirtle.api-layers.squirtle-elemental-api"

---@class SquirtleBasicApi : SquirtleElementalApi
local SquirtleBasicApi = {}
setmetatable(SquirtleBasicApi, {__index = SquirtleElementalApi})

---@param target integer
---@param current? integer
function SquirtleBasicApi.face(target, current)
    current = current or SquirtleElementalApi.getFacing()

    if not current then
        error("facing not available")
    end

    if (current + 2) % 4 == target then
        SquirtleElementalApi.turn("back")
    elseif (current + 1) % 4 == target then
        SquirtleElementalApi.turn("right")
    elseif (current - 1) % 4 == target then
        SquirtleElementalApi.turn("left")
    end

    return target
end

---Throws an error if:
--- - no digging tool is equipped
--- - turtle is not allowed to dig the block
---@param direction? string
---@return boolean success
function SquirtleBasicApi.mine(direction)
    local success, message = SquirtleBasicApi.tryMine(direction)

    -- if there is no message, then there just wasn't anything to dig, meaning every other case is interpreted as an error
    if not success and message then
        error(message)
    end

    return success
end

---Throws an error if:
--- - no digging tool is equipped
---@param direction? string
---@return boolean success, string? error
function SquirtleBasicApi.tryMine(direction)
    if State.simulate then
        return true
    end

    direction = direction or "forward"
    local native = getNative("dig", direction)
    local block = SquirtleElementalApi.probe(direction)

    if not block then
        return false
    elseif not State.canBreak(block) then
        return false, string.format("not allowed to mine block %s", block.name)
    end

    local success, message = native()

    if not success then
        if message == "Nothing to dig here" then
            return false
        elseif string.match(message, "tool") then
            error(string.format("failed to mine %s: %s", direction, message))
        end
    end

    return success, message
end

---@param side? string
---@param text? string
---@return boolean, string?
function SquirtleBasicApi.tryReplace(side, text)
    if State.simulate then
        return true
    end

    if SquirtleElementalApi.place(side, text) then
        return true
    end

    while SquirtleBasicApi.tryMine(side) do
    end

    return SquirtleElementalApi.place(side, text)
end

---@param sides? string[]
---@param text? string
---@return string?
function SquirtleBasicApi.tryReplaceAtOneOf(sides, text)
    if State.simulate then
        error("tryReplaceAtOneOf() can't be simulated")
    end

    sides = sides or {"top", "front", "bottom"}

    for i = 1, #sides do
        local side = sides[i]

        if SquirtleElementalApi.place(side, text) then
            return side
        end
    end

    -- [todo] tryPut() is attacking - should we do it here as well?
    for i = 1, #sides do
        local side = sides[i]

        while SquirtleBasicApi.tryMine(side) do
        end

        if SquirtleElementalApi.place(side, text) then
            return side
        end
    end
end

---@param fuel integer
---@return boolean
function SquirtleBasicApi.hasFuel(fuel)
    local level = SquirtleElementalApi.getFuelLevel()

    return level == "unlimited" or level >= fuel
end

---@param limit? integer
---@return integer
function SquirtleBasicApi.missingFuel(limit)
    local current = SquirtleElementalApi.getFuelLevel()

    if current == "unlimited" then
        return 0
    end

    return (limit or SquirtleElementalApi.getFuelLimit()) - current
end

---@param slot integer
---@return boolean
function SquirtleBasicApi.selectIfNotEmpty(slot)
    if SquirtleElementalApi.getItemCount(slot) > 0 then
        return SquirtleElementalApi.select(slot)
    else
        return false
    end
end

---@param startAt? number
---@return integer
function SquirtleBasicApi.selectEmpty(startAt)
    startAt = startAt or turtle.getSelectedSlot()

    for i = 0, SquirtleBasicApi.size() - 1 do
        local slot = startAt + i

        if slot > SquirtleBasicApi.size() then
            slot = slot - SquirtleBasicApi.size()
        end

        if SquirtleBasicApi.getItemCount(slot) == 0 then
            SquirtleBasicApi.select(slot)

            return slot
        end
    end

    error("no empty slot available")
end

---@return integer
function SquirtleBasicApi.selectFirstEmpty()
    return SquirtleBasicApi.selectEmpty(1)
end

---@param startAt? number
function SquirtleBasicApi.firstEmptySlot(startAt)
    -- [todo] this startAt logic works a bit differently to "Backpack.selectEmpty()" as it does not wrap around
    startAt = startAt or 1

    for slot = startAt, SquirtleBasicApi.size() do
        if SquirtleBasicApi.getItemCount(slot) == 0 then
            return slot
        end
    end

    return nil
end

---@return integer
function SquirtleBasicApi.numEmptySlots()
    local numEmpty = 0

    for slot = 1, SquirtleBasicApi.size() do
        if SquirtleBasicApi.getItemCount(slot) == 0 then
            numEmpty = numEmpty + 1
        end
    end

    return numEmpty
end

---@return boolean
function SquirtleBasicApi.isFull()
    for slot = 1, SquirtleBasicApi.size() do
        if SquirtleBasicApi.getItemCount(slot) == 0 then
            return false
        end
    end

    return true
end

---@return boolean
function SquirtleBasicApi.isEmpty()
    for slot = 1, SquirtleBasicApi.size() do
        if SquirtleBasicApi.getItemCount(slot) > 0 then
            return false
        end
    end

    return true
end

---@return ItemStack[]
function SquirtleBasicApi.getStacks()
    local stacks = {}

    for slot = 1, SquirtleBasicApi.size() do
        local item = SquirtleBasicApi.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@param predicate string|function<boolean, ItemStack>
---@return integer
function SquirtleBasicApi.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStack
        ---@type function<boolean, ItemStack>
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(SquirtleBasicApi.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

---@return table<string, integer>
function SquirtleBasicApi.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(SquirtleBasicApi.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param name string
---@param exact? boolean
---@param startAtSlot? integer
---@return integer?
function SquirtleBasicApi.find(name, exact, startAtSlot)
    startAtSlot = startAtSlot or 1

    for slot = startAtSlot, SquirtleBasicApi.size() do
        local item = SquirtleBasicApi.getStack(slot)

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
function SquirtleBasicApi.has(item, minCount)
    if type(minCount) == "number" then
        return SquirtleBasicApi.getItemStock(item) >= minCount
    else
        for slot = 1, SquirtleBasicApi.size() do
            local stack = SquirtleBasicApi.getStack(slot)

            if stack and stack.name == item then
                return true
            end
        end

        return false
    end
end

function SquirtleBasicApi.condense()
    if State.simulate then
        return nil
    end

    for slot = SquirtleBasicApi.size(), 1, -1 do
        local item = SquirtleBasicApi.getStack(slot)

        if item then
            for targetSlot = 1, slot - 1 do
                local candidate = SquirtleBasicApi.getStack(targetSlot, true)

                if candidate and candidate.name == item.name and candidate.count < candidate.maxCount then
                    SquirtleBasicApi.select(slot)
                    SquirtleBasicApi.transferTo(targetSlot)

                    if SquirtleBasicApi.getItemCount(slot) == 0 then
                        break
                    end
                elseif not candidate then
                    SquirtleBasicApi.select(slot)
                    SquirtleBasicApi.transferTo(targetSlot)
                    break
                end
            end
        end
    end
end

return SquirtleBasicApi
