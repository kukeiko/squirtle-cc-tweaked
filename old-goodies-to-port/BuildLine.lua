-- [todo] this app served me well in building simple yet textured towers.
-- it looks fairly complex, so want to port it eventually as well
local BuildLine = {}

--- <summary>
--- </summary>
--- <returns type="BuildLine"></returns>
function BuildLine.new()
    local instance = {}
    setmetatable(instance, {__index = BuildLine})
    instance:ctor()

    return instance
end

function BuildLine:ctor()
end

function BuildLine:run()
    MessagePump.run()

    local squirtle = System.Squirtle.new()
    local pickaxe = Components.Squirtle.Pickaxe.cast(squirtle:base():loadComponent("Squirtle.Pickaxe"))
    local movement = Components.Squirtle.Movement.cast(squirtle:base():loadComponent("Squirtle.Movement"))
    local fuel = Components.Squirtle.Fueling.cast(squirtle:base():loadComponent("Squirtle.Fueling"))
    local inv = Components.Squirtle.Inventory.cast(squirtle:base():loadComponent("Squirtle.Inventory"))

    local ui = UI.ConsoleUI.new()

    local buildLength = ui:getInt("How many blocks?")
    local direction = ui:getChoice("Direction?", {"FRONT", "UP", "DOWN"})
    direction = _G[direction]

    local buildDirection = FRONT
    if (direction == FRONT) then
        buildDirection = DOWN
    end

    local numVariations = ui:getInt("How many variations?", 1)
    local variationBlocks = {}

    -- number of blocks for one full variation sequence
    local numSequence = 0

    for i = 1, numVariations do
        ui:printDashLine()
        print("Put variation " .. i .. " @ slot " .. i .. ".")
        print("<press any key to confirm>")

        local item
        local useNoItem = false

        while (true) do
            MessagePump.pull("key")
            item = inv:get(i)

            if (item ~= nil) then
                break
            elseif (numVariations > 1) then
                useNoItem = ui:getBool("Use no blocks for variation " .. i .. "?")

                if (useNoItem) then
                    break
                end
            end
        end

        if (useNoItem) then
            variationTimes = ui:getInt("How often should I skip placing?", 1)
        else
            if (numVariations > 1) then
                variationTimes = ui:getInt("How often should I place" .. item:getId() .. ":" .. item:getDamage() .. "?",
                                           1)
            else
                variationTimes = buildLength
            end

        end

        numSequence = numSequence + variationTimes
        table.insert(variationBlocks, {item = item, times = variationTimes})
    end

    local buildSequence = {}

    for i = 1, #variationBlocks do
        local times = variationBlocks[i].times
        local item = variationBlocks[i].item

        if (item ~= nil) then
            local blocksRequired = math.ceil(buildLength / numSequence) * times
            local actualQuantity = inv:getTotalItemQuantity(item:getId(), item:getDamage())

            while (actualQuantity < blocksRequired) do
                ui:printDashLine()
                print("Need " .. item:getId() .. ":" .. item:getDamage() .. " x" .. blocksRequired .. ", has " ..
                          actualQuantity)
                print("<press any key to continue>")
                MessagePump.pull("key")
                actualQuantity = inv:getTotalItemQuantity(item:getId(), item:getDamage())
            end
        else
            item = {empty = true}
        end

        for e = 1, times do
            table.insert(buildSequence, item)
        end
    end

    local offset = 0

    if (numVariations > 1) then
        offset = ui:getInt("Offset?", 0, #buildSequence - 1)
    end

    local comeBack = ui:getBool("Come back?")

    for i = 1, offset do
        local last = table.remove(buildSequence)
        table.insert(buildSequence, 1, last)
    end

    local blocksBuilt = 0
    local complete = false

    while (not complete) do
        for i = 1, #buildSequence do
            local item = buildSequence[i]

            if (not item.empty) then
                inv:select(inv:findItem(item:getId(), times, item:getDamage()))
                pickaxe:dig(buildDirection)
                squirtle:place(buildDirection)
            end

            blocksBuilt = blocksBuilt + 1

            if (blocksBuilt >= buildLength) then
                complete = true
                break
            end

            movement:moveAggressive(direction)
        end
    end

    if (comeBack) then
        if (direction == FRONT) then
            movement:turn(LEFT, 2)
        end

        local backDirection = FRONT

        if (direction == UP) then
            backDirection = DOWN
        elseif (direction == DOWN) then
            backDirection = UP
        end

        for i = 1, blocksBuilt - 1 do
            movement:moveAggressive(backDirection)
        end
    end
end

if (Apps == nil) then
    Apps = {}
end
Apps.BuildLine = BuildLine
