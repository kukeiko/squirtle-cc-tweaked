local Inventory = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.Inventory"></returns>
function Inventory.new(squirtle)
    local instance = Components.Squirtle.Component.new(squirtle, "Squirtle.Inventory")

    setmetatable(Inventory, { __index = Components.Squirtle.Component })
    setmetatable(instance, { __index = Inventory })

    instance:ctor()

    return instance
end

function Inventory:ctor()

end

--- <summary>instance: (Inventory)</summary>
--- <returns type="Components.Squirtle.Inventory"></returns>
function Inventory.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Inventory:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Inventory.super()
    return Components.Squirtle.Component
end

function Inventory:load()
    Inventory.super().load(self)
    self:condense()
end

--- <summary>
--- slot: (number) slot number (1-15)
--- </summary>
--- <returns type="Item"></returns>
function Inventory:get(slot)
    local itemDetail = turtle.getItemDetail(slot)
    if (itemDetail == nil) then return nil end

    return Item.fromItemDetail(itemDetail)
end

function Inventory:getId(slot)
    local item = self:get(slot)
    if (item == nil) then return nil end

    return item:getId()
end

function Inventory:getItems()
    local items = { }

    for slot = 1, self:numSlots() do
        local item = self:get(slot)

        if (item ~= nil) then
            table.insert(items, slot, item)
        end
    end

    return items
end

function Inventory:getQuantity(slot)
    return turtle.getItemCount(slot)
end

function Inventory:getMissingQuantity(slot)
    return turtle.getItemSpace(slot)
end

function Inventory:select(slot)
    turtle.select(slot)
end

function Inventory:transfer(fromSlot, toSlot, quantity)
    quantity = quantity or self:maxStackQuantity()
    self:select(fromSlot)

    turtle.transferTo(toSlot, quantity)
end

function Inventory:getTotalItemQuantity(itemId, damage)
    local quantity = 0

    for slot = 1, self:numSlots() do
        if (self:slotContainsItem(slot, itemId, 1, damage)) then
            quantity = quantity + self:getQuantity(slot)
        end
    end

    return quantity
end

function Inventory:findItem(id, quantity, damage)
    quantity = quantity or 1

    if (quantity > self:maxStackQuantity()) then error("Quantity bigger than " .. self:maxStackQuantity()) end

    local results = { }
    local quantityFound = 0

    for slot = 1, self:numSlots() do
        if (self:slotContainsItem(slot, id, 1, damage)) then
            local slotQuantity = self:getQuantity(slot)
            local result = { slot = slot, quantity = slotQuantity }
            table.insert(results, result)

            quantityFound = quantityFound + slotQuantity

            if (quantityFound >= quantity) then
                break
            end
        end
    end

    if (quantityFound < quantity) then return nil end
    if (#results == 1) then return results[1].slot end

    for i = #results, 2, -1 do
        self:transfer(results[i].slot, results[1].slot, results[i].quantity)
    end

    return results[1].slot
end

function Inventory:slotContainsItem(slot, id, quantity, damage)
    local item = self:get(slot)
    if (item == nil) then return false end

    if (id ~= nil and item:getId() ~= id) then return false end
    if (quantity ~= nil and item:getQuantity() < quantity) then return false end
    if (damage ~= nil and item:getDamage() ~= damage) then return false end

    return true
end

function Inventory:condense()
    for slot = 1, self:numSlots() do
        if (self:getQuantity(slot) == 0) then
            local nextNonEmptySlot = self:firstNonEmptySlot(slot)

            if (nextNonEmptySlot == nil) then
                break
            end

            self:transfer(nextNonEmptySlot, slot)
        end

        self:condenseSlot(slot)
    end
end

--- if strict = true: function must amass items @ condensed slot; not allowed to stack @ beginning of Inventory
function Inventory:condenseSlot(condenseSlot, strict)
    strict = strict or false

    local item = self:get(condenseSlot)
    if (item == nil) then return nil end
    if (item:getQuantity() == self:maxStackQuantity()) then return nil end

    for slot = 1, self:numSlots() do
        if (self:slotContainsItem(slot, item:getId()) and slot ~= condenseSlot) then
            local fromSlot = slot
            local toSlot = condenseSlot

            if (not strict and condenseSlot > slot) then
                fromSlot = condenseSlot
                toSlot = slot
            end

            if (self:getQuantity(toSlot) ~= self:maxStackQuantity()) then
                self:transfer(fromSlot, toSlot, self:getMissingQuantity(toSlot))

                if (self:getQuantity(condenseSlot) == self:maxStackQuantity()) then
                    break
                end
            end
        end
    end
end

function Inventory:numSlots()
    return 16
end

function Inventory:maxStackQuantity()
    return 64
end

function Inventory:firstEmptySlot(start)
    start = start or 1
    if (start < 1 or start > self:numSlots()) then error("slot out of range") end

    for slot = start, self:numSlots() do
        if (self:getQuantity(slot) == 0) then
            return slot
        end
    end
end

function Inventory:firstNonEmptySlot(start)
    start = start or 1
    if (start < 1 or start > self:numSlots()) then error("slot out of range") end

    for slot = start, self:numSlots() do
        if (self:getQuantity(slot) > 0) then
            return slot
        end
    end
end

function Inventory:hasEmptySlot()
    return self:firstEmptySlot() ~= nil
end

function Inventory:hasEmptySlots(num)
    return self:numEmptySlots() >= num
end

function Inventory:numEmptySlots()
    local num = 0

    for slot = 1, self:numSlots() do
        if (self:getQuantity(slot) == 0) then
            num = num + 1
        end
    end

    return num
end

function Inventory:selectFirstEmptySlot()
    local slot = self:firstEmptySlot()

    if (slot == nil) then
        error("No empty slot to select")
    end

    self:select(slot)
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.Inventory = Inventory