---@class MonitorModemProxy
local MonitorModemProxy = {remoteName = "", modem = {}}

function MonitorModemProxy.new(remoteName, modem)
    local instance = {remoteName = remoteName, modem = modem}

    setmetatable(instance, {__index = MonitorModemProxy})

    return instance
end

function MonitorModemProxy:clear()
    return self.modem.callRemote(self.remoteName, "clear")
end

function MonitorModemProxy:getSize()
    return self.modem.callRemote(self.remoteName, "getSize")
end

function MonitorModemProxy:setCursorPos(x, y)
    return self.modem.callRemote(self.remoteName, "setCursorPos", x, y)
end

function MonitorModemProxy:write(text)
    return self.modem.callRemote(self.remoteName, "write", text)
end

return MonitorModemProxy;
