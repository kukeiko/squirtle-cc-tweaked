local SquirtleV2 = require "squirtle.squirtle-v2"

local function printUsage()
    print("Usage:")
    print("build-platform <depth> <width> [bottom|top]")
end

local function refuel(level)
    if SquirtleV2.hasFuel(level) then
        return true
    end

    shell.run("refuel", "all")

    while not SquirtleV2.hasFuel(level) do
        print(string.format("[help] not enough fuel, need %d more.", SquirtleV2.getMissingFuel(level)))
        print("please put some into inventory")
        os.pullEvent("turtle_inventory")
        shell.run("refuel", "all")
    end
end

---@return integer
local function countItems()
    local total = 0

    for slot = 1, 16 do
        total = total + turtle.getItemCount(slot)
    end

    return total
end

---@param target integer
local function ensureHasBlocks(target)
    local current = countItems()

    while current < target do
        print(string.format("[help] not enough blocks, need %d more", target - current))
        print("please put some into inventory")
        os.pullEvent("turtle_inventory")
        current = countItems()
    end
end

---@param args table<string>
---@return BuildPlatformAppState? state
return function(args)
    local depth = tonumber(args[1])
    local width = tonumber(args[2])
    local topOrBottom = args[3]

    if not topOrBottom then
        topOrBottom = "bottom"
    end

    if not depth or not width or depth < 1 or width < 1 or (topOrBottom ~= "bottom" and topOrBottom ~= "top") then
        printUsage()
        return nil
    end

    local returnTripFuel = math.abs(depth) + math.abs(width)
    local numBlocks = math.abs(depth) * math.abs(width)
    print(numBlocks .. "x blocks")

    local requiredFuel = math.ceil((numBlocks + returnTripFuel) * 1.2)
    refuel(requiredFuel)
    os.sleep(1)
    ensureHasBlocks(numBlocks)

    ---@type BuildPlatformAppState
    local state = {depth = depth, width = width, direction = topOrBottom}

    return state
end
