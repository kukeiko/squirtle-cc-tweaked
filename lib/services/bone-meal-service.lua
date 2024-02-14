---@class BoneMealService : Service
local BoneMealService = {name = "bone-meal"}

function BoneMealService.on()
    redstone.setOutput("bottom", false)
end

function BoneMealService.off()
    redstone.setOutput("bottom", true)
end

return BoneMealService
