local DeliveryDonna = { }

--- <summary>
--- </summary>
--- <returns type="DeliveryDonna"></returns>
function DeliveryDonna.new()
    local instance = { }
    setmetatable(instance, { __index = DeliveryDonna })
    instance:ctor()

    return instance
end

function DeliveryDonna:ctor()
end

function DeliveryDonna:run()
    MessagePump.run()


    --    local movement = Components.Squirtle.MovementComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Movement"))
    --    local feeder = Components.Squirtle.DeliveryDonnaComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.DeliveryDonna"))
    --    local inv = Components.Squirtle.InventoryComponent.cast(squirtle:base():installAndLoadComponent("Squirtle.Inventory"))
    --    local ui = UI.ConsoleUI.new()
    local squirtle = System.Squirtle.new()

    local getChestItemCount = function(chest)
        local stacks = chest.getAllStacks()
        local count = 0
        for k, v in pairs(stacks) do
            count = count + 1
        end

        return count
    end

    while (true) do
        local chest = peripheral.wrap("bottom")

        while (getChestItemCount(chest) == 0) do
            print("Chest is empty, recheck in 3...")
            os.sleep(3)
        end

        for i = 1, 16 do
            turtle.suckDown()
        end

        while (turtle.up()) do end

        turtle.turnRight()

        local stillHasItems = false

        while (true) do
            for i = 1, 16 do
                turtle.select(i)
                turtle.drop()
                if (turtle.getItemCount(i) > 0) then
                    stillHasItems = true
                end
            end

            if (stillHasItems) then
                local otherChest = peripheral.wrap("front")

                while (getChestItemCount(otherChest) == otherChest.getInventorySize()) do
                    print("Chest is full, recheck in 3...")
                    os.sleep(3)
                end
            else
                break
            end

            stillHasItems = false
        end

        turtle.turnLeft()

        while (turtle.down()) do end
    end
end

if (Apps == nil) then Apps = { } end
Apps.DeliveryDonna = DeliveryDonna