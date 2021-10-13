local Services = { }

--- <summary></summary>
--- <returns type="Services"></returns>
function Services.new(unit)
    local instance = { }
    setmetatable(instance, { __index = Services })

    instance:ctor(unit)

    return instance
end

function Services:ctor(unit)
    self._unit = Squirtle.Unit.as(unit)
    self._terminal = Kevlar.Terminal.new()
end

function Services:run()
    self._header = Kevlar.Header.new("Services", "-", self._terminal:sub(1, 1, "*", 2))
    self:mainMenu(self._terminal:sub(1, 3, "*", "*"))
end

function Services:mainMenu(buffer)
    local sel = Kevlar.Sync.Select.new(buffer)

    if (self._unit:numSleepingServices() > 0) then sel:addOption("Start", function() self:startService(buffer) end) end
    if (self._unit:numRunningServices() > 0) then sel:addOption("Stop", function() self:stopService(buffer) end) end
    if (self._unit:numRunningServices() > 0) then sel:addOption("Configure", function() self:configService(buffer) end) end
    
    local result = sel:run()
    if(result == nil) then return end

    result()
    self:mainMenu(buffer)
end

function Services:startService(buffer)
    local sel = Kevlar.Sync.Select.new(buffer)
    local sleeping = self._unit:getSleepingServices()

    for k, v in pairs(sleeping) do
        sel:addOption(k, k)
    end

    local name = sel:run()
    if(name == nil) then return end

    self._unit:startService(name)
end

function Services:configService(buffer)
    local sel = Kevlar.Sync.Select.new(buffer)
    local running = self._unit:getRunningServices()

    for k, v in pairs(running) do
        sel:addOption(k, k)
    end

    local name = sel:run()
    if(name == nil) then return end

    self._header:setText("Services: " .. name)
    self._unit:configService(name, buffer)
    self._header:setText("Services")
end

function Services:stopService(buffer)
    local sel = Kevlar.Sync.Select.new(buffer)
    local running = self._unit:getRunningServices()

    for k, v in pairs(running) do
        sel:addOption(k, k)
    end

    local name = sel:run()
    if(name == nil) then return end

    self._unit:stopService(name)
end

if (Apps == nil) then Apps = { } end
Apps.Services = Services