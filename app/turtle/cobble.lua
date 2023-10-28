local function collect()
    turtle.select(1)

    while turtle.getItemSpace(16) > 0 do
        turtle.digDown()
    end
end

local function lookAtChest()
    for _ = 1, 4 do
        local _, block = turtle.inspect()

        if block and block.name == "minecraft:chest" then
            return
        end

        turtle.turnRight()
    end

    error("no chest found :(")
end

local function dump()
    lookAtChest()

    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            turtle.select(slot)

            if not turtle.drop() or turtle.getItemCount(slot) > 0 then
                return false
            end
        end
    end

    return true
end

local function main()
    print("[cobble v1.0.0] booting...")
    lookAtChest()
    print("[ready] to collect!")

    while true do
        collect()

        if not dump() then
            print("[help] chest is full")
        end

        repeat
            os.sleep(7)
        until dump()

        print("[ok] dumped all!")
    end
end

main()
