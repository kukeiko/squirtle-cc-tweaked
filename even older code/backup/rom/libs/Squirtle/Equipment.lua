local Equipment = { }

--- <summary>
--- </summary>
--- <returns type="Squirtle.Equipment"></returns>
function Equipment.new(turtleApi, inventory)
    local instance = { }
    setmetatable(instance, { __index = Equipment })
    instance:ctor(turtleApi, inventory)

    return instance
end

--- <summary>
--- </summary>
--- <returns type="Squirtle.Equipment"></returns>
function Equipment.as(instance)
    return instance
end

function Equipment:ctor(turtleApi, inventory)
    self._turtleApi = Squirtle.TurtleApi.as(turtleApi)
    self._inventory = Squirtle.Inventory.as(inventory)

    self._cachedLeftItemId = nil
    self._cachedRightItemId = nil
    self._leftSideLocked = false
    self._rightSideLocked = false
    self._isUnlockedSideRequired = false
end

function Equipment:load()
    if (not self._inventory:hasEmptySlot()) then
        error("Equipment: requires 1 free inventory slot")
    end

    self._cachedLeftItemId = self:identifySide(LEFT)
    self._cachedRightItemId = self:identifySide(RIGHT)
end

function Equipment:tryEquip(itemId)
    return pcall( function() self:equip(itemId) end)
end

function Equipment:equip(itemId)
    if (self:isEquipped(itemId)) then
        local side = self:sideOfEquippedItem(itemId)
        Log.debug("equip", itemId, "already equipped")
        return peripheral.wrap(SIDES[side]), side
    end

    if (self:areBothSidesLocked()) then
        error("Can't equip: both Equipment slots are locked")
    end

    local slot = self._inventory:findItem(itemId)

    if (not slot) then
        error("Can't equip: " .. itemId .. " not in inventory")
    end

    local side = self:getAnyUnlockedSide()

    Log.debug("equip", itemId, "equipping now")
    self._inventory:select(slot)
    self._turtleApi:equip(side)

    if (side == LEFT) then
        self._cachedLeftItemId = itemId
    else
        self._cachedRightItemId = itemId
    end

    if (not peripheral.isPresent(SIDES[side])) then
        return nil
    end

    return peripheral.wrap(SIDES[side]), side
end

function Equipment:equipAndLock(itemId)
    if (self:numLockedSides() == 1 and self:isUnlockedSideRequired()) then
        error("Can't equip & lock: 1 unlocked Equipment slot is required")
    end

    local item = self:equip(itemId)
    local side = self:sideOfEquippedItem(itemId)

    if (side == LEFT) then
        self._leftSideLocked = true
    else
        self._rightSideLocked = true
    end

    return item, side
end

function Equipment:requireUnlockedSide()
    if (self:areBothSidesLocked()) then
        error("Cant reserve 1 free slot: both slots are already locked")
    end

    self._isUnlockedSideRequired = true
end

function Equipment:unequip()
    local numEquipped = self:numEquipped()

    self._inventory:condense()

    if (not self._inventory:hasEmptySlots(numEquipped)) then
        error("Can't unequip: not enough inventory space")
    end

    self._inventory:selectFirstEmptySlot()
    self._turtleApi:equip(LEFT)
    self._inventory:selectFirstEmptySlot()
    self._turtleApi:equip(RIGHT)

    self._cachedLeftItemId = nil
    self._cachedRightItemId = nil
    self._leftSideLocked = false
    self._rightSideLocked = false
    self._isUnlockedSideRequired = false
end

function Equipment:areBothSidesLocked()
    return self:isLeftSideLocked() and self:isRightSideLocked()
end

function Equipment:couldOrIsEquipped(itemId)
    if (self:isEquipped(itemId)) then return true end

    if (self:areBothSidesLocked()) then
        return false, "Both sides are locked"
    end

    if (not self._inventory:findItem(itemId)) then
        return false, "Squirtle.Item not found"
    end

    return true
end

function Equipment:identifySide(side)
    local itemId = self:duckTypeSide(side)
    if (itemId) then return itemId end

    self._inventory:selectFirstEmptySlot()

    if (self._turtleApi:equip(side)) then
        itemId = self._inventory:getId()
        self._turtleApi:equip(side)
        return itemId
    end
end

--- <summary>
--- Tries to identify an item via duck typing
--- side: side of equipped item to duck type
--- </summary>
--- <returns type="string"></returns>
function Equipment:duckTypeSide(side)
    local sideName = SIDES[side]
    if (not peripheral.isPresent(sideName)) then return nil end

    local p = peripheral.wrap(sideName)
    if (not p) then return nil end

    local pType = peripheral.getType(sideName)

    local chunkyModemItemId = "chunkyperipherals:WirelessChunkyModuleItem"
    local chunkyPickaxeItemId = "chunkyperipherals:MinyChunkyModuleItem"
    local chunkyItemId = "chunkyperipherals:TurtleChunkLoaderItem"

    -- chunky peripherals
    if (p.isChunky) then
        if (pType == "Miny Chunky Module") then
            return chunkyPickaxeItemId
        elseif (pType == "modem") then
            return chunkyModemItemId
        elseif (pType == "Chunky Module") then
            return chunkyItemId
        end
    end

    -- compass
    if (p.getFacing) then
        return "minecraft:compass"
    end
end

function Equipment:getAnyUnlockedSide()
    if (not self:isLeftSideLocked()) then
        return LEFT
    end

    if (not self:isRightSideLocked()) then
        return RIGHT
    end
end

function Equipment:isEquipped(itemId)
    if (itemId == self._cachedLeftItemId) then
        return true, LEFT
    elseif (itemId == self._cachedRightItemId) then
        return true, RIGHT
    end

    return false
end

--- Checks if the left side is locked.
function Equipment:isLeftSideLocked()
    return self._leftSideLocked
end

--- Checks if the right side is locked.
function Equipment:isRightSideLocked()
    return self._rightSideLocked
end

--- Checks if one slot is required to be unlocked.
function Equipment:isUnlockedSideRequired()
    return self._isUnlockedSideRequired
end

function Equipment:numEquipped()
    local num = 0

    if (self._cachedLeftItemId ~= nil) then
        num = num + 1
    end

    if (self._cachedRightItemId ~= nil) then
        num = num + 1
    end

    return num
end

function Equipment:numLockedSides()
    local num = 0

    if (self:isLeftSideLocked()) then
        num = num + 1
    end

    if (self:isRightSideLocked()) then
        num = num + 1
    end

    return num
end

function Equipment:sideOfEquippedItem(itemId)
    if (itemId == self._cachedLeftItemId) then
        return LEFT
    elseif (itemId == self._cachedRightItemId) then
        return RIGHT
    end
end

if (Squirtle == nil) then Squirtle = { } end
Squirtle.Equipment = Equipment