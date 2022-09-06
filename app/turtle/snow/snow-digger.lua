local function isFull()
    return turtle.getItemCount(16) == 16
end

local function main()
    turtle.select(1)

    while true do
        if isFull() then
            print("Full! sleeping for 30s")
            os.sleep(30)
        end

        for _ = 1, 16 do
            turtle.dig()
        end
    end
end

main()
