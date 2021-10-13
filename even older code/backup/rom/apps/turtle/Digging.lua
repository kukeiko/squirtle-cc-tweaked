local Digging = { }

function Digging.new(unit, buffer)
    local instance = { }
    setmetatable(instance, { __index = Digging })

    instance:ctor(unit, buffer)

    return instance
end

function Digging:ctor(unit, buffer)
    self._turtle = Squirtle.Turtle.as(unit)
    self._buffer = Kevlar.IBuffer.as(buffer)
    self._inv = self._turtle:getInventory()
    self._network = nil    
end

function Digging:run()
    local header = Kevlar.Header.new("Digging", "-", self._buffer:sub(1, 1, "*", 1))
    local content = self._buffer:sub(1, 3, "*", "*")

    self:mainMenu(content)
end

function Digging:mainMenu(buffer)
    local sel = Kevlar.Sync.Select.new(buffer)

    sel:addOption("Dig a Line", function()
        self:digLine(buffer)
    end)

    sel:addOption("Dig a Chunk", function()
        self:digChunk(buffer)
    end )

    local result = sel:run()
    if (result == nil) then return end

    result()
    self:mainMenu(buffer)
end

function Digging:digLine(buffer)
    local wiz = Kevlar.Sync.Wizard.new(buffer)
    local num = wiz:getInt("How many?", 1)
    local doReturn = wiz:getBool("Return?")

    for i = 1, num do
        self._turtle:dig(FRONT)
        self._turtle:moveAggressive(FRONT)
    end

    if (doReturn) then
        self._turtle:turn(LEFT, 2)
        self._turtle:moveAggressive(FRONT, num)
    end

    self._turtle:turn(LEFT, 2)
end

function Digging:digChunk(buffer)
    local depot = self:selectDepot(buffer)
    if (depot == nil) then return end

    local wiz = Kevlar.Sync.Wizard.new(buffer)
    local discoverDepth = wiz:getBool("Discover?")

    local width = 16
    local depth = 16
    self._inv:reserve("minecraft:dirt", 1)

    local toChunkOrigin = function()
        local chunkCenter = self._turtle:currentChunkOrigin()
        local success = pcall( function() self._turtle:navigateTo(chunkCenter) end)

        if (not success) then
            self._turtle:moveToAggressive(chunkCenter)
        end
    end

    local discover = function()
        while (self._turtle:tryMovePeaceful(BOTTOM)) do end
        self._turtle:moveAggressive(DOWN)
    end
    
    local placeMarker = function()
        local slot = self._inv:findItem("minecraft:dirt")
        if (slot ~= nil) then
            self._inv:select(slot)
            self._turtle:getTurtleApi():place(DOWN)
        end
    end

    local dump = function()
        local checkpoint = self._turtle:getLocation()
        self._turtle:navigateTo(depot:getLocation() + Squirtle.Vector.new(0, 1, 0), { })
        self._inv:dump(DOWN)
        self._turtle:navigateTo(checkpoint, { })
    end

    local digLine = function()
        self._turtle:moveAggressive(FRONT, depth - 1)
    end

    toChunkOrigin()

    if (discoverDepth) then
        discover()
    end

    while (self._turtle:getLocation().y > 5) do
        toChunkOrigin()
        self._turtle:turnToOrientation(SOUTH)

        for x = 1, width do
            digLine()

            self._inv:condense()

            if (self._inv:numEmptySlots() <= 3) then
                dump()
            end

            if (x < width) then
                if (x % 2 == 0) then
                    self._turtle:turnToOrientation(EAST)
                    self._turtle:moveAggressive(FRONT)
                    self._turtle:turnToOrientation(SOUTH)
                else
                    self._turtle:turnToOrientation(EAST)
                    self._turtle:moveAggressive(FRONT)
                    self._turtle:turnToOrientation(NORTH)
                end
            end
        end

        toChunkOrigin()
        discover()
        placeMarker()
    end
end


--- <summary>
--- </summary>
--- <returns type="Entities.Depot"></returns>
function Digging:selectDepot(buffer)
    local service = self:getDepotClient()
    local depots = service:all()
    local sel = Kevlar.Sync.Select.new(buffer:sub(1, 1, "*", "*"))

    for i = 1, #depots do
        sel:addOption(depots[i]:toString(), depots[i])
    end

    return sel:run()
end

--- <summary>
--- </summary>
--- <returns type="Clients.Depots"></returns>
function Digging:getDepotClient()
    if (self._depots == nil) then
        self._depots = Clients.Depots.nearest(self._turtle:getWirelessAdapter())
    end

    return self._depots:refresh()
end

if (Apps == nil) then Apps = { } end
Apps.Digging = Digging