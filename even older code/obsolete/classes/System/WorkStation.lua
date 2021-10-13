local Workstation = { }

--- <summary>
--- </summary>
--- <returns type="Workstation"></returns>
function Workstation.new()
    local instance = System.Computer.new()

    setmetatable(Workstation, { __index = System.Computer })
    setmetatable(instance, { __index = Workstation })

    return instance
end

--- <summary>
--- Helper for BabeLua autocomplete
--- </summary>
--- <returns type="System.Workstation"></returns>
function Workstation:base()
    return self
end

function Workstation:foo()
    return "Workstation"
end

if (System == nil) then System = { } end
System.Workstation = Workstation