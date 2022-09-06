local function isFull()
    return turtle.getItemCount(16) == 16
end

local function main()
    turtle.select(1)

    local firstItem = turtle.getItemDetail(1)
    if firstItem and firstItem.name == "minecraft:snow_block" then
        turtle.dropDown()
    end

    while true do
        for slot = 1, 4 do
            while turtle.getItemCount(slot) < 16 do
                turtle.select(slot)
                turtle.suck(16 - turtle.getItemCount(slot))
                os.sleep(3)
            end
        end

        turtle.craft()
        turtle.select(1)
        turtle.dropDown()
    end
end

main()
