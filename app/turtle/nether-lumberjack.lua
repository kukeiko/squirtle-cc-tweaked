if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Vector = require "lib.models.vector"
local DatabaseApi = require "lib.apis.database.database-api"
local TurtleApi = require "lib.apis.turtle.turtle-api"
local ItemApi = require "lib.apis.item-api"
local RemoteService = require "lib.systems.runtime.remote-service"

-- [note] we want exactly 63 so that 1x stack of charcoal in the i/o chest is enough
local minFuel = 63 * ItemApi.getRefuelAmount(ItemApi.charcoal)
local minBoneMealForWork = 32
local minFungiForWork = 1
local barrel = "front"
local chest = "bottom"
local maxGrowthHeight = 27 -- have not seen a bigger one yet
local harvestHeight = 9 -- have not seen more wart blocks vertically yet

---@param variant "crimson" | "warped"
local function ensureNylium(variant)
    TurtleApi.move()

    if TurtleApi.probe("bottom", ItemApi.getNylium(variant)) then
        TurtleApi.move("back")
    else
        -- [todo] I'm thinking of adding "trySelectItem()" and "tryPlace()" to TurtleApi and make "selectItem()" and "place()" error
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
    print("Usage: nether-lumberjack <height> <\"crimson\"|\"warped\">")
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
        if not TurtleApi.suckItem(barrel, ItemApi.diskDrive, 1) then
            TurtleApi.requireItem(ItemApi.diskDrive)
        end
    end

    TurtleApi.orientate("disk-drive", {"top"})
    TurtleApi.setPosition(Vector.create(0, 0, 0))
end

---@param variant "crimson" | "warped"
local function climb(variant)
    for _ = 1, maxGrowthHeight do
        if not TurtleApi.isSimulating() and not TurtleApi.probe("top", ItemApi.getStem(variant)) then
            TurtleApi.mine("top")
            TurtleApi.move("up")
            break
        end

        TurtleApi.mine("top")
        TurtleApi.move("up")
    end
end

---@param variant "crimson" | "warped"
local function resumableClimb(variant)
    DatabaseApi.createTurtleResumable({
        args = {}, -- [note] not used
        home = Vector.create(0, 0, 0), -- [note] not used
        initialState = {facing = TurtleApi.getFacing(), fuel = TurtleApi.getNonInfiniteFuelLevel(), position = TurtleApi.getPosition()},
        name = "nether-lumberjack:climb",
        options = {}, -- [note] not used
        randomSeed = 0, -- [note] not used
        state = {} -- [note] not used
    })
    climb(variant)
    DatabaseApi.deleteTurtleResumable("nether-lumberjack:climb")
end

local function harvest()
    local facing = TurtleApi.getFacing()
    TurtleApi.move("back", 3)
    TurtleApi.turn("left")
    TurtleApi.move("forward", 3)
    TurtleApi.turn("right")
    -- [todo] limit harvestHeight based on current y position
    local adjustedHarvestHeight = -math.min(TurtleApi.getPosition().y - 1, harvestHeight)
    TurtleApi.digArea(7, 7, adjustedHarvestHeight, Vector.create(0, 1, 0), facing)
    TurtleApi.move("down")
end

local function resumableHarvest()
    DatabaseApi.createTurtleResumable({
        args = {}, -- [note] not used
        home = Vector.create(0, 0, 0), -- [note] not used
        initialState = {facing = TurtleApi.getFacing(), fuel = TurtleApi.getNonInfiniteFuelLevel(), position = TurtleApi.getPosition()},
        name = "nether-lumberjack:harvest",
        options = {}, -- [note] not used
        randomSeed = 0, -- [note] not used
        state = {} -- [note] not used
    })
    harvest()
    DatabaseApi.deleteTurtleResumable("nether-lumberjack:harvest")
end

print(string.format("[nether-lumberjack %s] booting...", version()))

EventLoop.run(function()
    RemoteService.run({"nether-lumberjack"})
end, function()
    ---@type "crimson" | "warped"
    local variant = arg[1]

    if not (variant == "crimson" or variant == "warped") then
        return printUsage()
    end

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

    local climbResumable = DatabaseApi.findTurtleResumable("nether-lumberjack:climb")
    local harvestResumable = DatabaseApi.findTurtleResumable("nether-lumberjack:harvest")

    if (climbResumable or harvestResumable) and TurtleApi.probe(chest, ItemApi.chest) then
        -- [note] turtle was reset by player, don't resume
        DatabaseApi.deleteTurtleResumable("nether-lumberjack:climb")
        DatabaseApi.deleteTurtleResumable("nether-lumberjack:harvest")
        climbResumable = nil
        harvestResumable = nil
    end

    if climbResumable or harvestResumable then
        while not TurtleApi.selectItem(ItemApi.diskDrive) do
            TurtleApi.requireItem(ItemApi.diskDrive)
        end

        TurtleApi.orientate("disk-drive")
        local resumable = climbResumable or harvestResumable --[[@as TurtleResumable]]
        TurtleApi.resume(resumable.initialState.fuel, resumable.initialState.facing, resumable.initialState.position)
    end

    if climbResumable then
        climb(variant)
        DatabaseApi.deleteTurtleResumable("nether-lumberjack:climb")
        -- [todo] tiny chance when switching from climbing to harvest that we can't resume if chunk unload
        -- happened between deleting climb resumable file and creating harvest resumable file
        resumableHarvest()
    elseif harvestResumable then
        harvest()
        DatabaseApi.deleteTurtleResumable("nether-lumberjack:harvest")
    else
        recover()
    end

    while true do
        local inputItems = {[ItemApi.boneMeal] = minBoneMealForWork, [ItemApi.getFungus(variant)] = minFungiForWork}
        TurtleApi.transferOutputInput(barrel, chest, inputItems)
        TurtleApi.refuelTo(minFuel, barrel, chest)
        TurtleApi.suckAll(barrel)
        TurtleApi.move("up")
        TurtleApi.move()

        if not TurtleApi.probe("forward", ItemApi.getStem(variant)) then
            ensureNylium(variant)
            plant(variant)
        end

        TurtleApi.move()
        resumableClimb(variant)
        -- [todo] tiny chance when switching from climbing to harvest that we can't resume if chunk unload
        -- happened between deleting climb resumable file and creating harvest resumable file
        resumableHarvest()
    end
end)
