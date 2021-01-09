package.path = package.path .. ";/libs/?.lua"

---@class Workspace
local Workspace = {}

function Workspace.new()
    local instance = {}

    setmetatable(instance, {__index = Workspace})

    return instance
end

function Workspace:setInventory()
    self.inventory = {}
end

function Workspace:hasInventory()
    return self.inventory ~= nil
end

function Workspace:assertHasInventory()
    if not self:hasInventory() then
        error("workspace has no inventory")
    end
end

function Workspace:setInput(side, type)
    self.input = {side = side, type = type}
end

function Workspace:hasInput()
    return self.input ~= nil
end

function Workspace:wrapInput()
    return peripheral.wrap(self.input.side), self.input.side
end

function Workspace:assertHasInput()
    if not self:hasInput() then
        error("workspace has no input")
    end
end

function Workspace:addStash()
end

function Workspace:hasStash()
end

function Workspace:setBuffer(side, type)
    self.buffer = {side = side, type = type}
end

function Workspace:hasBuffer()
    return self.buffer ~= nil
end

function Workspace:assertHasBuffer()
    if not self:hasBuffer() then
        error("workspace has no buffer")
    end
end

function Workspace:wrapBuffer()
    return peripheral.wrap(self.buffer.side), self.buffer.side
end

function Workspace:setOutput(side, type)
    self.output = {side = side, type = type}
end

function Workspace:hasOutput()
    return self.output ~= nil
end

function Workspace:wrapOutput()
    return peripheral.wrap(self.output.side), self.output.side
end

return Workspace
