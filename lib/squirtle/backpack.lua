local native = turtle

local Backpack = {}

---@param slot integer
---@param detailed? boolean
---@return ItemStackV2?
function Backpack.getStack(slot, detailed)
    return native.getItemDetail(slot, detailed)
end

-- [todo] idea: cache stacks until any event is pulled.
-- that should - afaik - be completely safe, as any change in turtle inventory triggers a "turtle_inventory" event
---@return ItemStack[]
function Backpack.getStacks()
    local stacks = {}

    for slot = 1, 16 do
        local item = Backpack.getStack(slot)

        if item then
            stacks[slot] = item
        end
    end

    return stacks
end

---@return table<string, integer>
function Backpack.getStock()
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(Backpack.getStacks()) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    return stock
end

---@param predicate string|function<boolean, ItemStackV2>
function Backpack.getItemStock(predicate)
    if type(predicate) == "string" then
        local name = predicate

        ---@param stack ItemStackV2
        predicate = function(stack)
            return stack.name == name
        end
    end

    local stock = 0

    for _, stack in pairs(Backpack.getStacks()) do
        if predicate(stack) then
            stock = stock + stack.count
        end
    end

    return stock
end

return Backpack;
