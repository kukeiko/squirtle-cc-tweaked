local DigChunk = { }

--- <summary>
--- </summary>
--- <returns type="DigChunk"></returns>
function DigChunk.new()
    local instance = { }
    setmetatable(instance, { __index = DigChunk })
    instance:ctor()

    return instance
end

function DigChunk:ctor()
    self._squirtle = System.Squirtle.new()
    self._squirtle:base():installAndLoadComponent("Squirtle.Movement")
    self._squirtle:base():installAndLoadComponent("Squirtle.Pickaxe")
    self._squirtle:base():installAndLoadComponent("Squirtle.Inventory")
    self._squirtle:base():installAndLoadComponent("Location")
    self._startY = nil
    self._start = nil
end

function DigChunk:run()
    MessagePump.run()

    local squirtle = self._squirtle
    local ui = UI.ConsoleUI.new()

    local loc = self:getLocation()
    local mov = self:getMovement()
    local inv = self:getInventory()
    local pickaxe = self:getPickaxe()

    self._startY = ui:getInt("Start Y? (current is "..loc:getLocation().y..")")

    local chestIsAboveMe = false

    while (true) do
        local item = inv:get(1)
        if (item and item:isChest()) then
            break
        end

        local p = peripheral.wrap("top")
        if (p and p.pullItem) then
            chestIsAboveMe = true
            break
        end

        print("Please put a chest into slot #1, then press any key")
        MessagePump.pull("key")
    end

    local targetLayer = ui:getInt("Until layer?", 0, self._startY - 1)

    if (not chestIsAboveMe) then
        inv:select(1)
        pickaxe:dig(UP)
        self._squirtle:place(UP)
    end

    self._start = loc:getLocation()

    local getChestItemCount = function(chest)
        local stacks = chest.getAllStacks()
        local count = 0
        for k, v in pairs(stacks) do
            count = count + 1
        end

        return count
    end

    local deltaY = self._startY - targetLayer
    local nextLayer = 1

    for i = 1, deltaY do
        self:moveToLayer(i)
        self:digCurrentLayer()
        nextLayer = nextLayer + 1
        mov:moveToAggressive(self._start)
        for e = 1, 16 do
            inv:select(e)
            self._squirtle:drop(UP)
        end

        local chest = peripheral.wrap("top")

        while (getChestItemCount(chest) == chest.getInventorySize()) do
            print("Chest is full, recheck in 10...")
            os.sleep(10)
        end
    end
end

function DigChunk:moveToLayer(layer)
    local loc = self:getLocation()
    local layerOrigin = loc:getHorizontalChunkOrigin()
    layerOrigin.y = self._startY - layer
    self:getMovement():moveToAggressive(layerOrigin)
end

function DigChunk:digCurrentLayer()
    local mov = self:getMovement()
    local pickaxe = self:getPickaxe()
    mov:turnToOrientation(SOUTH)

    for i = 1, 16 do
        mov:moveAggressive(FRONT, 15)
        local turnDir = LEFT

        if (i % 2 == 0) then
            turnDir = RIGHT
        end

        if (i ~= 16) then
            mov:turn(turnDir)
            mov:moveAggressive(FRONT, 1)
            mov:turn(turnDir)
        end
    end
end

--- <summary></summary>
--- <returns type="Components.LocationComponent"></returns>
function DigChunk:getLocation()
    return self._squirtle:base():getComponent("Location")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.MovementComponent"></returns>
function DigChunk:getMovement()
    return self._squirtle:base():getComponent("Squirtle.Movement")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.PickaxeComponent"></returns>
function DigChunk:getPickaxe()
    return self._squirtle:base():getComponent("Squirtle.Pickaxe")
end

--- <summary></summary>
--- <returns type="Components.Squirtle.InventoryComponent"></returns>
function DigChunk:getInventory()
    return self._squirtle:base():getComponent("Squirtle.Inventory")
end

--if (Apps == nil) then Apps = { } end
--Apps.DigChunk = DigChunk