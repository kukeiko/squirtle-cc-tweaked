---@return boolean, boolean
local function hasApple()
    local hasSomethingElse = false

    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            local item = turtle.getItemDetail(slot)

            if item then
                if item.name == "minecraft:apple" then
                    return true, false
                else
                    hasSomethingElse = true
                end
            end
        end
    end

    return false, hasSomethingElse
end

term.clear()
term.setCursorPos(1, 1)

print("I really could go for a healthy treat!")

while true do
    os.pullEvent("turtle_inventory")
    local hasBook, hasSomethingElse = hasApple()
    local wrongs = {"Don't wanna eat that!", "I want something else!", "Are you trying to kill me?"}

    term.clear()
    term.setCursorPos(1, 1)

    if hasBook then
        print("That's perfect!\n")
        os.sleep(1)
        print("Please take this as a thank you!\n")
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
        os.sleep(.25)
        redstone.setOutput("bottom", true)
        os.sleep(.25)
        redstone.setOutput("bottom", false)
        os.sleep(1)
        os.pullEvent("never")
    elseif hasSomethingElse then
        print(wrongs[math.random(1, #wrongs)])
    else
        print("I really could go for a healthy treat!")
    end
end
