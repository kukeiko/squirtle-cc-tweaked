local Feeding = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.Feeding"></returns>
function Feeding.new(squirtle)
    local instance = Components.Squirtle.Component.new(squirtle, "Squirtle.Feeding", { "Squirtle.Equipment", "Squirtle.Inventory" })

    setmetatable(Feeding, { __index = Components.Squirtle.Component })
    setmetatable(instance, { __index = Feeding })

    instance:ctor()

    return instance
end

function Feeding:ctor()

end

--- <summary></summary>
--- <returns type="Components.Squirtle.Equipment"></returns>
function Feeding:getEquipment()
    return self:base():getDependency("Squirtle.Equipment")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Inventory"></returns>
function Feeding:getInventory()
    return self:base():getDependency("Squirtle.Inventory")
end

--- <summary>instance: (Feeding)</summary>
--- <returns type="Components.Squirtle.Feeding"></returns>
function Feeding.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Feeding:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Feeding.super()
    return Components.Squirtle.Component
end

function Feeding:load()
    Feeding.super().load(self)

    local itemId = self:getFeedingItemId()
    local eq = self:getEquipment()

    if (not eq:couldOrIsEquipped(itemId)) then
        error("Feeding: failed couldOrIsEquipped check: " .. itemId)
    end

    eq:requireUnlockedSide()
end

function Feeding:feed()
    local Feeding = self:equipFeeding()
    local inv = self:getInventory()
    local wheatSlot = inv:findItem("minecraft:wheat")

    inv:select(wheatSlot)

    return Feeding.feed()
end

function Feeding:getFeedingItemId()
    return "PeripheralsPlusPlus:FeedingUpgrade"
end

function Feeding:equipFeeding()
    return self:getEquipment():equip(self:getFeedingItemId())
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.Feeding = Feeding