local Fueling = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.Fueling"></returns>
function Fueling.new(squirtle)
    local instance = Components.Squirtle.Component.new(squirtle, "Squirtle.Fuel", { "Squirtle.Inventory" })

    setmetatable(Fueling, { __index = Components.Squirtle.Component })
    setmetatable(instance, { __index = Fueling })

    instance:ctor()

    return instance
end

function Fueling:ctor()
    self._isUnlimitedMode = turtle.getFuelLimit() == "unlimited"
    self._fuelItemIds = {
        "minecraft:lava_bucket",
        "minecraft:coal_block",
        "minecraft:coal"
    }
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Inventory"></returns>
function Fueling:getInventory()
    return self:base():getDependency("Squirtle.Inventory")
end

--- <summary>instance: (Fueling)</summary>
--- <returns type="Components.Squirtle.Fueling"></returns>
function Fueling.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Fueling:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Fueling.super()
    return Components.Squirtle.Component
end

function Fueling:load()
    Fueling.super().load(self)
end

function Fueling:isUnlimitedMode()
    return self._isUnlimitedMode
end

function Fueling:getFuelLevel()
    return turtle.getFuelLevel()
end

function Fueling:getFuelLimit()
    return turtle.getFuelLimit()
end

function Fueling:getLevelToFull()
    if (self:isUnlimitedMode()) then return 0 end

    return self:getFuelLimit() - self:getFuelLevel()
end

function Fueling:isFull()
    if (self:isUnlimitedMode()) then return true end

    return self:getFuelLevel() == self:getFuelLimit()
end

function Fueling:hasFuel(num)
    if (self:isUnlimitedMode()) then return true end

    num = num or 1

    return self:getFuelLevel() >= num
end

function Fueling:getFuelItemIds()
    return self._fuelItemIds
end

function Fueling:refuel(toFuelLevel)
    if (self:isUnlimitedMode()) then return nil end

    toFuelLevel = toFuelLevel or 1

    if (self:getFuelLevel() >= toFuelLevel) then
        return nil
    end

    if (toFuelLevel > self:getFuelLimit()) then
        error("Fueling: required refuel level is bigger than fuel limit")
    end

    local inv = self:getInventory()
    
    for k, fuelId in pairs(self:getFuelItemIds()) do
        while(self:getFuelLevel() < toFuelLevel) do
            local slot = inv:findItem(fuelId)

            if(slot) then
                inv:select(slot)
                turtle.refuel(1)
            else
                break
            end
        end

        if(self:getFuelLevel() >= toFuelLevel) then
            return nil
        end
    end

    error("Fueling: failed to reach required fuel level")
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.Fueling = Fueling