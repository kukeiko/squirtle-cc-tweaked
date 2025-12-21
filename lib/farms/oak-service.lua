---@class OakService : Service
local OakService = {name = "oak",maxDistance = 32}

local isOn = false

function OakService.on()
    isOn = true
end

function OakService.isOn()
    return isOn
end

function OakService.off()
    isOn = false
end

return OakService
