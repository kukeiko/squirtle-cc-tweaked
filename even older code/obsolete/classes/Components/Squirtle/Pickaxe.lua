local Pickaxe = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.Pickaxe"></returns>
function Pickaxe.new(squirtle)
    local instance = Components.Squirtle.Component.new(squirtle, "Squirtle.Pickaxe", { "Squirtle.Equipment" })

    setmetatable(Pickaxe, { __index = Components.Squirtle.Component })
    setmetatable(instance, { __index = Pickaxe })

    instance:ctor()

    return instance
end

function Pickaxe:ctor()

end

--- <summary>instance: (Pickaxe)</summary>
--- <returns type="Components.Squirtle.Pickaxe"></returns>
function Pickaxe.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Pickaxe:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Pickaxe.super()
    return Components.Squirtle.Component
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Equipment"></returns>
function Pickaxe:getEquipment()
    return self:base():getDependency("Squirtle.Equipment")
end

function Pickaxe:load()
    Pickaxe.super().load(self)
    
    local pickaxeId = self:getDiamondPickaxeId()
    local eq = self:getEquipment()

    if (not eq:couldOrIsEquipped(pickaxeId)) then
        error("Pickaxe: failed couldOrIsEquipped check")
    end

    eq:requireUnlockedSide()
end

function Pickaxe:attack(direction)
    direction = direction or FRONT

    local squirtle = self:base():getSquirtle()
    self:equipPickaxe()
    
    local success, e = squirtle:attack(direction)

    if (not success and e ~= "Nothing to attack here") then
        error("Pickaxe:attack: failed to attack: " .. e)
    end

    return success
end

function Pickaxe:attackStrict(direction)
    direction = direction or FRONT

    local squirtle = self:base():getSquirtle()
    self:equipPickaxe()

    local success, e = squirtle:attack(direction)

    if (not success) then
        error("Pickaxe:attack: failed to attack: " .. e)
    end

    return success
end

function Pickaxe:dig(direction)
    direction = direction or FRONT

    local squirtle = self:base():getSquirtle()
    self:equipPickaxe()

    local success, e = squirtle:dig(direction)

    if (not success and e ~= "Nothing to dig here") then
        error("Pickaxe:dig: failed to dig: " .. e)
    end

    return success
end

function Pickaxe:digStrict(direction)
    direction = direction or FRONT

    local squirtle = self:base():getSquirtle()
    self:equipPickaxe()

    local success, e = squirtle:dig(direction)

    if (not success) then
        error("Pickaxe:dig: failed to dig: " .. e)
    end
end

function Pickaxe:getDiamondPickaxeId()
    return "minecraft:diamond_pickaxe"
end

function Pickaxe:equipPickaxe()
    self:getEquipment():equip(self:getDiamondPickaxeId())
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.Pickaxe = Pickaxe