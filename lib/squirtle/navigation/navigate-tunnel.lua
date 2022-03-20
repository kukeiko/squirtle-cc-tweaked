return function(checkEarlyExit)
    local forbidden

    while true do
        local strategy

        if turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif forbidden ~= "up" and turtle.up() then
            strategy = "up"
            forbidden = "down"
        elseif forbidden ~= "down" and turtle.down() then
            strategy = "down"
            forbidden = "up"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and forbidden ~= "back" and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        elseif turtle.turnLeft() and turtle.forward() then
            strategy = "forward"
            forbidden = "back"
        else
            return true
        end

        if strategy == "forward" then
            while turtle.forward() do
            end
        elseif strategy == "up" then
            while turtle.up() do
            end
        elseif strategy == "down" then
            while turtle.down() do
            end
        end

        if checkEarlyExit ~= nil and checkEarlyExit() then
            return checkEarlyExit()
        end
    end
end
