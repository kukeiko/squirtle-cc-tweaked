local Utils = require "lib.tools.utils"
local ItemApi = require "lib.apis.item-api"
local InventoryPeripheral = require "lib.peripherals.inventory-peripheral"

---@class TurtleRefuelApi
local TurtleRefuelApi = {}

---@param stacks ItemStack[]
---@param fuel number
---@param allowLava? boolean
---@return ItemStack[] fuelStacks, number openFuel
local function pickFuelStacks(stacks, fuel, allowLava)
    local fuelItems = ItemApi.getFuelItems()
    local pickedStacks = {}
    local openFuel = fuel

    for slot, stack in pairs(stacks) do
        if fuelItems[stack.name] and (allowLava or stack.name ~= ItemApi.lavaBucket) then
            local itemRefuelAmount = fuelItems[stack.name]
            local numItems = math.ceil(openFuel / itemRefuelAmount)
            stack = Utils.clone(stack)
            stack.count = numItems
            pickedStacks[slot] = stack
            openFuel = openFuel - (numItems * itemRefuelAmount)

            if openFuel <= 0 then
                break
            end
        end
    end

    return pickedStacks, math.max(openFuel, 0)
end

---@param TurtleApi TurtleApi
---@param fuel? integer
---@param allowLava? boolean
local function refuelFromBackpack(TurtleApi, fuel, allowLava)
    fuel = fuel or TurtleApi.missingFuel()
    local fuelStacks = pickFuelStacks(TurtleApi.getStacks(), fuel, allowLava)
    local emptyBucketSlot = TurtleApi.find(ItemApi.bucket)

    for slot, stack in pairs(fuelStacks) do
        TurtleApi.select(slot)
        TurtleApi.refuel(stack.count)

        local remaining = TurtleApi.getStack(slot)

        if remaining and remaining.name == ItemApi.bucket then
            if not emptyBucketSlot or not TurtleApi.transferTo(emptyBucketSlot) then
                emptyBucketSlot = slot
            end
        end
    end
end

---@param TurtleApi TurtleApi
---@param fuel? integer
local function refuelWithHelpFromPlayer(TurtleApi, fuel)
    fuel = fuel or TurtleApi.missingFuel()
    local _, y = term.getCursorPos()

    while not TurtleApi.hasFuel(fuel) do
        term.setCursorPos(1, y)
        term.clearLine()
        local openFuel = fuel - TurtleApi.getFuelLevel()
        term.write(string.format("[help] need %d more fuel please", openFuel))
        term.setCursorPos(1, y + 1)
        os.pullEvent("turtle_inventory")
        refuelFromBackpack(TurtleApi, openFuel)
    end
end

---@param TurtleApi TurtleApi
---@param fuel integer
---@param barrel string?
---@param ioChest string?
function TurtleRefuelApi.refuelTo(TurtleApi, fuel, barrel, ioChest)
    if TurtleApi.hasFuel(fuel) then
        return true
    elseif fuel > TurtleApi.getFuelLimit() then
        error(string.format("required fuel is %d more than the tank can hold", fuel - TurtleApi.getFuelLimit()))
    end

    if barrel and ioChest then
        local function hasCharcoal()
            return InventoryPeripheral.getItemCount(barrel, ItemApi.charcoal) > 0
        end

        if not TurtleApi.hasFuel(fuel) and not hasCharcoal() then
            print("[waiting] for more charcoal to arrive")
        end

        while not TurtleApi.hasFuel(fuel) do
            TurtleApi.pullInput(ioChest, barrel)

            while not hasCharcoal() do
                TurtleApi.pullInput(ioChest, barrel)
                os.sleep(3)
            end

            local requiredCharcoal = math.ceil((fuel - TurtleApi.getFuelLevel()) / ItemApi.getRefuelAmount(ItemApi.charcoal))
            TurtleApi.selectEmpty(1)
            -- [todo] hardcoded value 64
            TurtleApi.suckItem(barrel, ItemApi.charcoal, math.min(requiredCharcoal, 64))
            TurtleApi.refuel()
        end

        print("[ready] have enough fuel:", TurtleApi.getFuelLevel())
    else
        refuelFromBackpack(TurtleApi, fuel)

        if not TurtleApi.hasFuel(fuel) then
            refuelWithHelpFromPlayer(TurtleApi, fuel)
        end
    end
end

return TurtleRefuelApi
