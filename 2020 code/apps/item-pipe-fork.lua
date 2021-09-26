print("[item-pipe-fork @ 1.0.0]")

local item = arg[1]

if type(item) ~= "string" then
    error("first argument must be a string")
end

print("[item] " .. item)

while true do
    for slot = 1, 16 do
        local stack = turtle.getItemDetail(slot)

        if stack then
            turtle.select(slot)

            if stack.name == arg[1] then
                turtle.dropDown()
            else
                turtle.drop()
            end
        end
    end

    os.sleep(3)
end
