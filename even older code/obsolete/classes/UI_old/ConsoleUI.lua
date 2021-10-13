local ConsoleUI = { }

--- <summary>
--- </summary>
--- <returns type="UI.ConsoleUI"></returns>
function ConsoleUI.new()
    local instance = { }

    setmetatable(instance, { __index = ConsoleUI })

    instance:ctor()

    return instance
end

function ConsoleUI:ctor(title)

end

function ConsoleUI:printDashLine()
    local w, h = term.getSize()

    print(string.rep("-", w))
end

function ConsoleUI:getInt(message, min, max)
    self:printDashLine()

    if (min ~= nil and max ~= nil) then
        message = message .. " (" .. min .. " - " .. max .. ")"
    elseif (min ~= nil) then
        message = message .. " (min. " .. min .. ")"
    elseif (max ~= nil) then
        message = message .. " (max. " .. max .. ")"
    end

    print(message)
    local value = nil

    while (value == nil or(min ~= nil and value < min) or(max ~= nil and value > max)) do
        value = tonumber(read())
    end

    return value
end

function ConsoleUI:getBool(message)
    self:printDashLine()
    print(message .. " (y/n)")
    local value = nil

    while (true) do
        value = read()
        if (value == "y") then return true end
        if (value == "n") then return false end
    end
end

function ConsoleUI:getChoice(message, choices)
    self:printDashLine()

    local choicesStr = ""

    for i = 1, #choices do
        choicesStr = choicesStr .. choices[i]

        if (i ~= #choices) then
            choicesStr = choicesStr .. ", "
        end
    end

    print(message .. " (" .. choicesStr .. ")")
    local value = nil

    while (true) do
        value = string.lower(read())

        for i = 1, #choices do
            if (string.lower(choices[i]) == value) then
                return choices[i]
            end
        end
    end

end
--- <summary>instance: (UI.ConsoleUI)</summary>
--- <returns type="UI.ConsoleUI"></returns>
function ConsoleUI.cast(instance)
    return instance
end

if (UI == nil) then UI = { } end
UI.ConsoleUI = ConsoleUI