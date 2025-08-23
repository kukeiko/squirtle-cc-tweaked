---@class Print3dService : Service
local Print3dService = {name = "print3d"}

local isOn = false

function Print3dService.on()
    isOn = true
end

function Print3dService.isOn()
    return isOn
end

function Print3dService.off()
    isOn = false
end

function Print3dService.abort()
    return os.queueEvent("print3d:abort")
end

return Print3dService
