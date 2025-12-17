---@class BoneMealService : Service
local BoneMealService = {name = "bone-meal"}
local isOn = true

function BoneMealService.isOn()
    return isOn
end

function BoneMealService.on()
    redstone.setOutput("bottom", false)
    isOn = true
end

function BoneMealService.off()
    redstone.setOutput("bottom", true)
    isOn = false
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
