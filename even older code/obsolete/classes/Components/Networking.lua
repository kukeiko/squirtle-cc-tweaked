local Networking = { }

--- <summary>
--- </summary>
--- <returns type="Components.Networking"></returns>
function Networking.new(computer)
    local instance = Components.Component.new(computer, "Networking")

    setmetatable(Networking, { __index = Components.Component })
    setmetatable(instance, { __index = Networking })

    if (computer:isTurtle()) then
        instance:addDependency("Squirtle.Equipment")
    end

    instance:ctor()

    return instance
end

function Networking:ctor()
    self._adapters = { }
end

--- <summary></summary>
--- <returns type="Components.Equipment"></returns>
function Networking:getEquipment()
    return self:base():getDependency("Squirtle.Equipment")
end

--- <summary>instance: (Networking)</summary>
--- <returns type="Components.Networking"></returns>
function Networking.cast(instance)
    return instance
end

--- <summary>Helper for BabeLua autocomplete</summary>
--- <returns type="Components.Component"></returns>
function Networking:base()
    return self
end

--- <summary>Helper to call base class functions</summary>
--- <returns type="Components.Component"></returns>
function Networking.super()
    return Components.Component
end

function Networking:load()
    Networking.super().load(self)

    if (self:base():getComputer():isTurtle()) then
        local eq = self:getEquipment()
        local modem, side = eq:equipAndLock(self:getChunkyWirelessModemId())
        local address = "Networking:" .. self:base():getComputer():getDeviceId()
        local wirelessAdapter = Network.NetworkAdapter.new(address, modem, side)
        
        table.insert(self._adapters, side, wirelessAdapter)
    end
end

function Networking:getAdapters()
    return self._adapters
end

--- <summary>
--- </summary>
--- <returns type="Networking.NetworkAdapter"></returns>
function Networking:getWirelessAdapter()
    for side, adapter in pairs(self:getAdapters()) do
        if (adapter:isWireless()) then
            return adapter
        end
    end
end

function Networking:getChunkyWirelessModemId()
    return "chunkyperipherals:WirelessChunkyModuleItem"
end

if (Components == nil) then Components = { } end
Components.Networking = Networking