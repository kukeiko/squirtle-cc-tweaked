---@return boolean, boolean
local function hasBook()
    ---@type integer[]
    local dropSlots = {}

    for slot = 1, 16 do
        if turtle.getItemCount(slot) > 0 then
            local item = turtle.getItemDetail(slot, true)

            if item then
                if item.displayName == "The Intricate Sex Life Of Turtles" then
                    return true, false
                else
                    table.insert(dropSlots, slot)
                end
            end
        end
    end

    for _, slot in ipairs(dropSlots) do
        turtle.select(slot)
        turtle.drop()
    end

    os.sleep(.5)

    return false, #dropSlots > 0
end

term.clear()
term.setCursorPos(1, 1)

print("I'm bored, I wish I had something to read...")

while true do
    os.pullEvent("turtle_inventory")
    local hasBook, hasSomethingElse = hasBook()
    local wrongs = {"That doesn't look interesting...", "Don't you have something else for me?", "That's awful, get it away from me!"}

    term.clear()
    term.setCursorPos(1, 1)

    if hasBook then
        print("Oh my, what a magnificent find!\n")
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
        print("I'd like  some alone time now if you don't mind...")
        os.pullEvent("never")
    elseif hasSomethingElse then
        print("I'm bored, I wish I had something to read...\n")
        print(wrongs[math.random(1, #wrongs)])
    else
        print("I'm bored, I wish I had something to read...")
    end
end
