---@class Monitor
local Monitor = {native = {}}

function Monitor.new(native)
    local instance = {native = native}

    setmetatable(instance, {__index = Monitor})

    return instance
end

function Monitor:clear()
    return self.native.clear()
end

function Monitor:getSize()
    return self.native.getSize()
end

function Monitor:setCursorPos(x, y)
    return self.native.setCursorPos(x, y)
end

function Monitor:write(text)
    return self.native.write(text)
end

return Monitor;
