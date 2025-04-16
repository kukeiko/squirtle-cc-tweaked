local Vector = require "lib.models.vector"
local Cardinal = require "lib.models.cardinal"
local DatabaseApi = require "lib.apis.database.database-api"
local TurtleStateApi = require "lib.apis.turtle.turtle-state-api"
local TurtleMiningApi = require "lib.apis.turtle.turtle-mining-api"
local TurtleMovementApi = require "lib.apis.turtle.turtle-movement-api"
local TurtleBuildingApi = require "lib.apis.turtle.turtle-building-api"

---@class TurtleLocationApi
local TurtleLocationApi = {}

function TurtleLocationApi.locate()
    local x, y, z = gps.locate()

    if not x then
        error("no gps available")
    end

    TurtleStateApi.setPosition(Vector.create(x, y, z))

    return TurtleStateApi.getPosition()
end

---@param position Vector
local function stepOut(position)
    TurtleMovementApi.refuelTo(2)

    if not TurtleMovementApi.tryWalk("forward") then
        return false
    end

    local now = TurtleLocationApi.locate()
    TurtleStateApi.setFacing(Cardinal.fromVector(Vector.minus(now, position)))

    while not TurtleMovementApi.tryWalk("back") do
        print("can't move back, something is blocking me. sleeping 1s...")
        os.sleep(1)
    end

    return true
end

---@param position Vector
---@param directions? MoveOrientationSide[]
---@return boolean
local function orientateSameLayer(position, directions)
    if stepOut(position) then
        return true
    end

    TurtleMovementApi.turn("left")

    if stepOut(position) then
        TurtleMovementApi.turn("right")
        return true
    end

    TurtleMovementApi.turn("left")

    if stepOut(position) then
        TurtleMovementApi.turn("back")
        return true
    end

    TurtleMovementApi.turn("left")

    if stepOut(position) then
        TurtleMovementApi.turn("left")
        return true
    end

    return false
end

local function addCleanupPlaceDirections(directions)
end

---@param directions? DiskDriveOrientationSide[]
---@return integer
local function orientateUsingDiskDrive(directions)
    if directions then
        for i = 1, #directions do
            if directions[i] ~= "top" and directions[i] ~= "bottom" then
                error(string.format("invalid disk-drive orientation direction: %s", directions[i]))
            end
        end
    end

    directions = directions or {"top", "bottom"}

    local diskState = DatabaseApi.getSquirtleDiskState()
    diskState.diskDriveSides = directions
    DatabaseApi.saveSquirtleDiskState(diskState)
    local placedSide = TurtleBuildingApi.tryPutAtOneOf(directions, "computercraft:disk_drive")

    if not placedSide then
        error("todo: need help from player")
    else
        diskState.diskDriveSides = {}
        diskState.cleanupSides[placedSide] = "computercraft:disk_drive"
        DatabaseApi.saveSquirtleDiskState(diskState)
    end

    -- while not SquirtleComplexApi.selectItem("computercraft:disk_drive") do
    --     SquirtleComplexApi.requireItems({["computercraft:disk_drive"] = 1})
    -- end

    -- -- [todo] should use tryPut() instead (which will also call requireItems())
    -- -- problem with that though is that tryPut() also mines, but I'd like to first
    -- -- try placing in all directions.
    -- local placedSide = Elemental.placeAtOneOf(directions)

    -- if not placedSide then
    --     -- [todo] should use (try?)mine() instead
    --     local dugSide = Elemental.digAtOneOf(directions)

    --     if not dugSide then
    --         error("todo: need help from player")
    --     end

    --     -- if not State.breakDirection or State.breakDirection == "front" then
    --     --     error("no space to put the disk drive")
    --     -- end

    --     -- -- [todo] should use put() instead - for that, put() needs to be pulled into at least this layer
    --     -- SquirtleComplexApi.mine(State.breakDirection)

    --     if not Basic.place(dugSide) then
    --         error("no space to put the disk drive")
    --     end

    --     placedSide = dugSide
    -- end

    while not peripheral.isPresent(placedSide) do
        os.sleep(.1)
    end

    local diskDrive = TurtleMiningApi.probe(placedSide, "computercraft:disk_drive")

    if not diskDrive then
        error("placed a disk-drive, but now it's gone")
    end

    if not diskDrive.state.facing then
        error("expected disk drive to have state.facing property")
    end

    local facing = Cardinal.rotateAround(Cardinal.fromName(diskDrive.state.facing))
    TurtleMiningApi.dig(placedSide)

    diskState.diskDriveSides[placedSide] = nil
    DatabaseApi.saveSquirtleDiskState(diskState)

    return facing
end

---@param method? OrientationMethod
---@param directions? OrientationSide[]
---@return integer facing
function TurtleLocationApi.orientate(method, directions)
    method = method or TurtleStateApi.getOrientationMethod()

    if method == "disk-drive" then
        TurtleStateApi.setFacing(orientateUsingDiskDrive(directions))
    else
        local position = TurtleLocationApi.locate()

        if not orientateSameLayer(position, directions) then
            error("failed to orientate. possibly blocked in.")
        end
    end

    return TurtleStateApi.getFacing()
end

return TurtleLocationApi
