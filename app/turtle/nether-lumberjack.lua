if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Vector = require "lib.models.vector"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local ItemApi = require "lib.apis.item-api"
local RemoteService = require "lib.systems.runtime.remote-service"
local Resumable = require "lib.apis.turtle.resumable"

---@param variant "crimson" | "warped"
local function ensureNylium(variant)
    TurtleApi.move()

    if TurtleApi.probe("bottom", ItemApi.getNylium(variant)) then
        TurtleApi.move("back")
    else
        -- [todo] ❌ I'm thinking of adding "trySelectItem()" and "tryPlace()" to TurtleApi and make "selectItem()" and "place()" error
        -- on failure so I don't need to do it here
        if not TurtleApi.selectItem(ItemApi.boneMeal) then
            error("expected to have bone meal")
        end

        if not TurtleApi.place("bottom") then
            error("failed to place bone meal - maybe there is no adjacent nylium?")
        end

        TurtleApi.move("back")
    end
end

---@param variant "crimson" | "warped"
local function plant(variant)
    TurtleApi.selectItem(ItemApi.getFungus(variant))
    TurtleApi.place()

    while not TurtleApi.probe("forward", ItemApi.getStem(variant)) do
        TurtleApi.selectItem(ItemApi.boneMeal)
        TurtleApi.place()
    end
end

local function printUsage()
    print("Usage: nether-lumberjack <\"crimson\"|\"warped\">")
end

local function recover()
    if not TurtleApi.probe("bottom", ItemApi.chest) then
        if TurtleApi.probe("bottom", ItemApi.barrel) then
            -- we're on the barrel, just move to the chest
            TurtleApi.move("back")
            TurtleApi.move("down")
        elseif not TurtleApi.probe("bottom") then
            -- we're assuming to be hovering over the chest
            TurtleApi.move("down")
        else
            -- assuming we're on top of the block we plant the tree
            TurtleApi.move("back", 2)
            TurtleApi.move("down")
        end
    end

    if not TurtleApi.probe("bottom", ItemApi.chest) then
        error("did not find home :(")
    end

    while not TurtleApi.selectItem(ItemApi.diskDrive) do
        if not TurtleApi.suckItem("front", ItemApi.diskDrive, 1) then
            TurtleApi.requireItem(ItemApi.diskDrive)
        end
    end

    TurtleApi.orientate("disk-drive", {"top"})
    TurtleApi.setPosition(Vector.create(0, 0, 0))
end

---@param variant "crimson" | "warped"
local function configureBreakable(variant)
    -- by setting an explicit list of blocks allowed to break we can make sure the turtle doesn't unintentionally destroy its surroundings in case of a bug.
    TurtleApi.setBreakable(function(block)
        return Utils.indexOf({
            ItemApi.getStem(variant),
            ItemApi.getFungus(variant),
            ItemApi.getWartBlock(variant),
            ItemApi.getVines(variant),
            ItemApi.getVinesPlant(variant),
            ItemApi.shroomlight
        }, block.name) ~= nil
    end)
end

print(string.format("[nether-lumberjack %s] booting...", version()))

EventLoop.run(function()
    RemoteService.run({"nether-lumberjack"})
end, function()

    local resumable = Resumable.new("nether-lumberjack")

    resumable:setStart(function(args, options)
        ---@type "crimson" | "warped"
        local variant = args[1]

        if not (variant == "crimson" or variant == "warped") then
            return printUsage()
        end

        ---@class NetherLumberjackAppState
        local state = {
            minFuel = 63 * ItemApi.getRefuelAmount(ItemApi.charcoal),
            minBoneMealForWork = 32,
            minFungiForWork = 1,
            maxGrowthHeight = 27, -- have not seen a bigger one yet
            harvestHeight = 9, -- have not seen more wart blocks vertically yet
            variant = variant
        }

        configureBreakable(variant)
        Utils.writeStartupFile(string.format("nether-lumberjack %s", variant))

        return state
    end)

    ---@param state NetherLumberjackAppState
    resumable:setResume(function(state, resumed)
        configureBreakable(state.variant)

        if resumed == "homework" then
            recover()
        elseif TurtleApi.probe("bottom", ItemApi.chest) then
            -- [todo] ❌ turtle was reset by player, don't resume
            error("manual turtle reset by player not yet implemented")
        else
            TurtleApi.orientate("disk-drive")
        end
    end)

    ---@param state NetherLumberjackAppState
    resumable:addMain("homework", function(state)
        local inputItems = {[ItemApi.boneMeal] = state.minBoneMealForWork, [ItemApi.getFungus(state.variant)] = state.minFungiForWork}
        TurtleApi.transferOutputInput("front", "bottom", inputItems)
        TurtleApi.refuelTo(state.minFuel, "front", "bottom")
        TurtleApi.suckAll("front")
        TurtleApi.move("up")
        TurtleApi.move()

        if not TurtleApi.probe("forward", ItemApi.getStem(state.variant)) then
            ensureNylium(state.variant)
            plant(state.variant)
        end

        TurtleApi.move()
    end)

    ---@param state NetherLumberjackAppState
    resumable:addSimulatableMain("climb", function(state)
        for _ = 1, state.maxGrowthHeight do
            if not TurtleApi.isSimulating() and not TurtleApi.probe("top", ItemApi.getStem(state.variant)) then
                TurtleApi.mine("top")
                TurtleApi.move("up")
                break
            end

            TurtleApi.mine("top")
            TurtleApi.move("up")
        end
    end)

    resumable:addSimulatableMain("harvest", function(state)
        local facing = TurtleApi.getFacing()
        TurtleApi.move("back", 3)
        TurtleApi.turn("left")
        TurtleApi.move("forward", 3)
        TurtleApi.turn("right")
        local adjustedHarvestHeight = -math.min(TurtleApi.getPosition().y - 1, state.harvestHeight)
        TurtleApi.digArea(7, 7, adjustedHarvestHeight, Vector.create(0, 1, 0), facing)
        TurtleApi.move("down")
    end)

    resumable:run(arg, true)
end)
