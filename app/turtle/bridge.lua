local function placeBlock()
    while true do
        for slot = 1, 16 do
            if turtle.getItemCount(slot) > 0 then
                turtle.select(slot)

                if turtle.placeDown() then
                    return true
                end
            end
        end

        print("[help] no more blocks to place")
        os.pullEvent("turtle_inventory")
    end
end

local function main()
    print("[bridge v1.0.0] booting...")

    local blocksFound = 0

    while blocksFound < 3 do
        if turtle.inspectDown() then
            blocksFound = blocksFound + 1
        else
            blocksFound = 0
            placeBlock()
        end

        if turtle.getFuelLevel() == 0 then
            print("[help] out of fuel, exiting")
            return
        end

        while not turtle.forward() do
            turtle.dig()
        end
    end
end

return main()
