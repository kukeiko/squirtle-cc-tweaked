local EventLoop = require "lib.tools.event-loop"

---@class BoneMealService : Service
local BoneMealService = {name = "bone-meal"}

function BoneMealService.run()
    while true do
        local event = EventLoop.pull()

        if event == "terminate" then
            return
        elseif event == "bone-meal:reboot" then
            os.reboot()
        end
    end
end

function BoneMealService.on()
    local isFull = BoneMealService.getStock()

    if not isFull then
        redstone.setOutput("bottom", false)
    end
end

function BoneMealService.off()
    redstone.setOutput("bottom", true)
end

function BoneMealService.reboot()
    EventLoop.queue("bone-meal:reboot")
end

---@return boolean, integer, string
function BoneMealService.getStock()
    local chest = peripheral.find("minecraft:chest")

    if not chest then
        return false, 0, "N/A"
    end

    ---@type ItemStack[]
    local items = chest.list()
    local stock = 0

    for _, item in pairs(items) do
        if item.name == "minecraft:bone_meal" then
            stock = stock + item.count
        end
    end

    -- minus one to account for name tag
    local chestSpace = (chest.size() - 1) * 64
    local percentage = string.format("%.0f%%", (stock / chestSpace) * 100)

    return stock >= chestSpace, stock, percentage
end

return BoneMealService
