local Control = { }

--- <summary>
--- </summary>
--- <returns type="Control"></returns>
function Control.new()
    local instance = { }
    setmetatable(instance, { __index = Control })
    instance:ctor()

    return instance
end

function Control:ctor()

end

function Control:run()
    local doQuit = false

    while (not doQuit) do
        local eventname, code = os.pullEvent("key")

        if (code == keys.w) then
            turtle.forward()
        elseif (code == keys.a) then
            turtle.turnLeft()
        elseif (code == keys.s) then
            turtle.down()
        elseif (code == keys.d) then
            turtle.turnRight()
        elseif (code == keys.space) then
            turtle.up()
        elseif (code == keys.q) then
            doQuit = true

            -- dig
        elseif (code == keys.r) then
            turtle.digUp()
        elseif (code == keys.f) then
            turtle.dig()
        elseif (code == keys.c) then
            turtle.digDown()

            -- place
        elseif (code == keys.t) then
            turtle.placeUp()
        elseif (code == keys.g) then
            turtle.place()
        elseif (code == keys.v) then
            turtle.placeDown()

            -- drop
        elseif (code == keys.z) then
            turtle.dropUp()
        elseif (code == keys.h) then
            turtle.drop()
        elseif (code == keys.b) then
            turtle.dropDown()

            -- suck
        elseif (code == keys.u) then
            turtle.suckUp()
        elseif (code == keys.j) then
            turtle.suck()
        elseif (code == keys.n) then
            turtle.suckDown()

            -- select
        elseif (code == keys.left) then
            local currentSlot = turtle.getSelectedSlot()

            currentSlot = currentSlot - 1

            if (currentSlot < 1) then
                currentSlot = 16
            end

            turtle.select(currentSlot)
        elseif (code == keys.right) then
            local currentSlot = turtle.getSelectedSlot()

            currentSlot = currentSlot + 1

            if (currentSlot > 16) then
                currentSlot = 1
            end

            turtle.select(currentSlot)
        elseif (code == keys.one) then
            print(turtle.getFuelLevel())
        elseif (code == keys.f1) then
            turtle.refuel()
        end
    end
end


if (Apps == nil) then Apps = { } end
Apps.Control = Control