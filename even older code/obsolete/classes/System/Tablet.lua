local Tablet = { }

--- <summary>
--- </summary>
--- <returns type="Tablet"></returns>
function Tablet.new()
    if (not pocket) then error("Not a pocket pc") end
    
    local instance = System.Computer.new()
    
    setmetatable(Tablet, { __index = System.Computer })
    setmetatable(instance, { __index = Tablet })

    return instance
end

--- <summary>
--- Helper for BabeLua autocomplete
--- </summary>
--- <returns type="System.Tablet"></returns>
function Tablet:base()
    return self
end

function Tablet:foo()
    return "Tablet"
end

if (System == nil) then System = { } end
System.Tablet = Tablet