local toIoInventory = require "inventory.to-io-inventory"

---@param chest string
---@param stacks table<integer, ItemStack>
---@param nameTagSlot integer
---@return NetworkedInventory
return function(chest, stacks, nameTagSlot)
    local ioInventory = toIoInventory(chest, stacks, nameTagSlot)

    ---@type NetworkedInventory
    local ioChest = {name = chest, type = "io", input = ioInventory.input, output = ioInventory.output}

    return ioChest
end
