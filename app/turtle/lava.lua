local function isLookingAtFullCauldron()
    local _, block = turtle.inspect()

    return block and block.name == "minecraft:lava_cauldron"
end

local function selectEmptyBucket()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            local item = turtle.getItemDetail(slot)

            if item.name == "minecraft:bucket" then
                turtle.select(slot)
                return true
            end
        end
    end

    return false;
end

local function selectLavaBucket()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 1 and turtle.getItemSpace(slot) == 0 then
            local item = turtle.getItemDetail(slot)

            if item.name == "minecraft:lava_bucket" then
                turtle.select(slot)
                return true
            end
        end
    end

    return false
end

local function waitUntilEmptyBucketSelected()
    if selectEmptyBucket() then
        return
    end

    print("[help] need empty bucket please!")

    repeat
        os.pullEvent("turtle_inventory")
    until selectEmptyBucket()

    print("[ok] thanks <3")
end

local function collectAll()
    for _ = 1, 4 do
        if isLookingAtFullCauldron() then
            waitUntilEmptyBucketSelected()
            turtle.place()
        end

        turtle.turnRight()
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

local function dumpLavaBucketsIntoChest()
    lookAtChest()

    while selectLavaBucket() do
        if not turtle.drop() then
            os.sleep(7)
        end
    end
end

local function main()
    print("[lava v1.0.0] booting...")
    lookAtChest() -- looking at chest so that collectAll() turns the right number of times
    print("[ready] to collect!")

    while true do
        collectAll()
        dumpLavaBucketsIntoChest()
        os.sleep(10)
    end
end

main()
