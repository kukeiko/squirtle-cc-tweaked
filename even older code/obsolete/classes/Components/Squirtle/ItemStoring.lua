local ItemStoring = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.ItemStoring"></returns>
function ItemStoring.new(squirtle)
    local instance = Components.Squirtle.Component.new(squirtle, "Squirtle.ItemStoring", { "Squirtle.Movement" })

    setmetatable(ItemStoring, { __index = Components.Squirtle.Component })
    setmetatable(instance, { __index = ItemStoring })

    instance:ctor()

    return instance
end

function ItemStoring:ctor()
    self._knownChests = { }
end

--- <summary></summary>
--- <returns type="Components.Squirtle.Movement"></returns>
function ItemStoring:getMovement()
    return self:base():getDependency("Squirtle.Movement")
end

--- <summary>instance: (ItemStoring)</summary>
--- <returns type="Components.Squirtle.ItemStoring"></returns>
function ItemStoring.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function ItemStoring:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function ItemStoring.super()
    return Components.Squirtle.Component
end

function ItemStoring:load()
    ItemStoring.super().load(self)

    --    if (not self:base():tableExists("data")) then
    --        self:base():saveTable("data", { })
    --    end

    --    local data = self:base():loadTable("data")

    --    if(data.chests) then
    --        for k, v in pairs(data.chests) do

    --        end
    --    end
end

function ItemStoring:addChest(location, name)
    table.insert(self._knownChests, { location = location, name = name })
end

function ItemStoring:moveToChest(name)
    local mov = self:getMovement()
    local chest = self:getChestByName(name)
    local loc = chest.location

    loc.y = loc.y + 1

    mov:moveToAggressive(loc)
end

function ItemStoring:getChestByName(name)
    for k, v in pairs(self._knownChests) do
        if (v.name == name) then
            return v
        end
    end
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.ItemStoring = ItemStoring