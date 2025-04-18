local Utils = require "lib.tools.utils"
local ItemApi = require "lib.apis.item-api"

-- [todo] add remaining
-- [todo] or, alternatively: make connection to StorageService mandatory and use its StorageService.getRequiredSlotCount()
local itemMaxCounts = {["minecraft:lava_bucket"] = 1, ["minecraft:water_bucket"] = 1, ["minecraft:bucket"] = 16}

---@param item string
---@return integer
local function getItemMaxCount(item)
    return itemMaxCounts[item] or 64
end

---@param items table<string, integer>
---@return integer
local function itemsToStacks(items)
    local numStacks = 0

    for item, numItems in pairs(items) do
        numStacks = numStacks + math.ceil(numItems / getItemMaxCount(item))
    end

    return numStacks
end

---@param TurtleApi TurtleApi
---@param items table<string, integer>
local function getMissing(TurtleApi, items)
    ---@type table<string, integer>
    local open = {}
    local stock = TurtleApi.getStock()

    for item, required in pairs(items) do
        local missing = required - (stock[item] or 0)

        if missing > 0 then
            open[item] = required - (stock[item] or 0)
        end
    end

    return open
end

---@param items table<string, integer>
---@param shulker string
local function getMissingInShulker(items, shulker)
    ---@type table<string, integer>
    local open = {}
    ---@type table<string, integer>
    local stock = {}

    for _, stack in pairs(peripheral.call(shulker, "list")) do
        stock[stack.name] = (stock[stack.name] or 0) + stack.count
    end

    for item, required in pairs(items) do
        local missing = required - (stock[item] or 0)

        if missing > 0 then
            open[item] = required - (stock[item] or 0)
        end
    end

    return open
end

---@param items table<string, integer>
local function printItemList(items)
    term.clear()
    term.setCursorPos(1, 1)
    local width, height = term.getSize()
    print("Required Items")
    print(string.rep("-", width))
    local line = 3

    ---@type { name: string, count: integer }[]
    local list = {}

    for item, count in pairs(items) do
        table.insert(list, {name = item, count = count})
    end

    table.sort(list, function(a, b)
        return a.count > b.count
    end)

    for _, item in ipairs(list) do
        term.setCursorPos(1, line)
        term.write(string.format("%dx %s", item.count, item.name))
        line = line + 1

        if line >= height then
            term.setCursorPos(1, line)
            term.write("...")
            break
        end
    end
end

---@param TurtleApi TurtleApi
---@param items table<string, integer>
---@param shulker string
local function fillShulker(TurtleApi, items, shulker)
    while not peripheral.isPresent(shulker) do
        os.sleep(.1)
    end

    local open = getMissingInShulker(items, shulker)

    while Utils.count(open) > 0 do
        printItemList(open)
        os.pullEvent("turtle_inventory")

        for slot = 1, TurtleApi.size() do
            local item = TurtleApi.getStack(slot)

            if item and item.name ~= ItemApi.shulkerBox then
                TurtleApi.select(slot)
                TurtleApi.drop(shulker)
            end
        end

        open = getMissingInShulker(items, shulker)
    end

    term.clear()
    term.setCursorPos(1, 1)
end

-- [todo] assumes that everything stacks to 64
---@param items table<string, integer>
---@param numStacks integer
---@return table<string, integer>, table<string, integer>
local function sliceNumStacksFromItems(items, numStacks)
    ---@type table<string, integer>
    local sliced = {}
    local remainingStacks = numStacks
    local leftOver = Utils.copy(items)

    for item, count in pairs(items) do
        local slicedCount = math.min(count, remainingStacks * getItemMaxCount(item))
        sliced[item] = slicedCount
        leftOver[item] = leftOver[item] - slicedCount

        if leftOver[item] == 0 then
            leftOver[item] = nil
        end

        remainingStacks = remainingStacks - math.ceil(slicedCount / getItemMaxCount(item))

        if remainingStacks == 0 then
            break
        end
    end

    return sliced, leftOver
end

---@param TurtleApi TurtleApi
---@param items table<string, integer>
local function requireItemsNoShulker(TurtleApi, items)
    local open = getMissing(TurtleApi, items)

    while Utils.count(open) > 0 do
        ---@type table<string, integer>
        printItemList(open)
        os.pullEvent("turtle_inventory")
        open = getMissing(TurtleApi, items)
    end

    term.clear()
    term.setCursorPos(1, 1)
end

---@param TurtleApi TurtleApi
---@param items table<string, integer>
local function requireItemsUsingShulker(TurtleApi, items)
    local numStacks = itemsToStacks(items)
    -- shulkers have 27 slots, but we want to keep one slot empty per shulker so that suckSlot() doesn't have to temporarily load an item from the shulker into the turtle inventory
    local maxStacksPerShulker = 26
    local numShulkers = math.ceil(numStacks / maxStacksPerShulker)
    local maxShulkers = TurtleApi.size() - 1

    -- [todo] assumes an empty inventory
    if numShulkers > maxShulkers then
        error(string.format("required items would need more than %d shulker boxes", maxShulkers))
    end

    requireItemsNoShulker(TurtleApi, {[ItemApi.shulkerBox] = numShulkers})
    ---@type table<string, true>
    local fullShulkers = {}
    local openItems = Utils.copy(items)

    for _ = 1, numShulkers do
        for slot = 1, 16 do
            local item = TurtleApi.getStack(slot, true)

            if item and item.name == ItemApi.shulkerBox and not fullShulkers[item.nbt] then
                TurtleApi.select(slot)
                local placedSide = TurtleApi.placeShulker()
                local itemsForShulker, leftOverFromSlice = sliceNumStacksFromItems(openItems, maxStacksPerShulker)
                openItems = leftOverFromSlice
                fillShulker(TurtleApi, itemsForShulker, placedSide)
                local shulkerSlot = TurtleApi.selectFirstEmpty()
                TurtleApi.digShulker(placedSide)
                local shulkerItem = TurtleApi.getStack(shulkerSlot, true)

                if not shulkerItem then
                    error("my shulker went poof :(")
                end

                fullShulkers[shulkerItem.nbt] = true
            end
        end
    end
end

---@param TurtleApi TurtleApi
---@param items table<string, integer>
---@param alwaysUseShulker boolean?
return function(TurtleApi, items, alwaysUseShulker)
    if Utils.isEmpty(items) then
        return
    end

    local numStacks = itemsToStacks(items)

    -- [todo] assumes an empty inventory. also, doesn't consider current inventory state (e.g. we might already have some items,
    -- yet we still count stacks of total items required)
    if alwaysUseShulker or numStacks > TurtleApi.size() then
        requireItemsUsingShulker(TurtleApi, items)
    else
        requireItemsNoShulker(TurtleApi, items)
    end
end
