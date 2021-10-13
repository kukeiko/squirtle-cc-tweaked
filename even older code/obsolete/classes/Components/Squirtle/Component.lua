local Component = { }

--- <summary>
--- </summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Component.new(squirtle, name, dependencies)
    local instance = Components.Component.new(squirtle, name, dependencies)
    
    setmetatable(Component, { __index = Components.Component })
    setmetatable(instance, { __index = Component })

    return instance
end

--- <summary>Returns the owner (squirtle) of this component.</summary>
--- <returns type="System.Squirtle"></returns>
function Component:getSquirtle()
    return self:base():getComputer()
end

--- <summary>instance: (Pickaxe)</summary>
--- <returns type="Components.Squirtle.Component"></returns>
function Component.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Component"></returns>
function Component:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Component"></returns>
function Component.super()
    return Components.Component
end

if (Components == nil) then Components = { } end
if (Components.Squirtle == nil) then Components.Squirtle = { } end
Components.Squirtle.Component = Component