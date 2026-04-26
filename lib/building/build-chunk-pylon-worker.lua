local Vector = require "lib.common.vector"
local Cardinal = require "lib.common.cardinal"
local Utils = require "lib.tools.utils"
local Rpc = require "lib.tools.rpc"
local StorageService = require "lib.inventory.storage-service"
local ItemApi = require "lib.inventory.item-api"
local TurtleTaskWorker = require "lib.system.turtle-task-worker"
local TurtleApi = require "lib.turtle.turtle-api"
local Resumable = require "lib.turtle.resumable"
local toBuildChunkPylonIterations = require "lib.building.to-build-chunk-pylon-iterations"
local ChunkPylonService = require "lib.building.chunk-pylon-service"

-- [todo] ❌ I'm thinking that the user should choose what kind of pylon should be built
local pylonMaterials = {ItemApi.deepslate, ItemApi.cobbled_deepslate, ItemApi.cobblestone, ItemApi.stone, ItemApi.dirt, ItemApi.grassBlock}
local pylonMaterialsDesert = {ItemApi.deepslate, ItemApi.stone, ItemApi.sandstone, ItemApi.sand}

---@class BuildChunkPylonWorker : TurtleTaskWorker 
local BuildChunkPylonWorker = {}
setmetatable(BuildChunkPylonWorker, {__index = TurtleTaskWorker})

---@param task BuildChunkPylonTask
---@param taskService TaskService | RpcClient
---@return BuildChunkPylonWorker
function BuildChunkPylonWorker.new(task, taskService)
    local instance = TurtleTaskWorker.new(task, taskService) --[[@as BuildChunkPylonWorker]]
    setmetatable(instance, {__index = BuildChunkPylonWorker})

    return instance
end

---@return TaskType
function BuildChunkPylonWorker.getTaskType()
    return "build-chunk-pylon"
end

---@return BuildChunkPylonTask
function BuildChunkPylonWorker:getTask()
    return self.task --[[@as BuildChunkPylonTask]]
end

function BuildChunkPylonWorker:work()
    local numShulkers = 4
    local task = self:getTask()
    local resumable = Resumable.new("build-chunk-pylon-worker")

    if not task.initialized then
        self:requireFuel(TurtleApi.getFiniteFuelLimit())
        self:requireShulkers(numShulkers)
        task.hubHome = TurtleApi.locate()
        task.hubFacing = TurtleApi.orientate("disk-drive")
        task.initialized = true
        self:updateTask()
    end

    if not task.navigated then
        TurtleApi.navigate(TurtleApi.getChunkCenter(task.chunkX, task.storageY, task.chunkZ))
        TurtleApi.face(Cardinal.south)
        task.navigated = true
        self:updateTask()
    end

    local fromLayer = Utils.isDev() and 55 or -59
    local toLayer = task.storageY - 1
    local totalLayers = toLayer - fromLayer

    if not task.iterations then
        local storage = Rpc.nearest(StorageService, nil, "wired")
        local storageStock = storage.getStock()
        -- [todo] ❌ type of materials to be read from task or sumthin'
        task.iterations = toBuildChunkPylonIterations(pylonMaterials, storageStock, numShulkers, totalLayers)
        self:updateTask()
    end

    local chunkCenter = TurtleApi.getChunkCenter(task.chunkX, task.storageY, task.chunkZ)
    local size = 14

    resumable:setStart(function(_, options)
        TurtleApi.locate()

        ---@class BuildChunkPylonState
        local state = {home = TurtleApi.getPosition(), facing = TurtleApi.orientate("disk-drive"), nextY = fromLayer}

        options.requireFuel = true

        return state
    end)

    resumable:setResume(function()
        TurtleApi.locate()
        TurtleApi.orientate("disk-drive")
    end)

    -- [todo] ❌ if top layer is a dirt layer, and there is grass in the storage:
    -- grab 1x grass block and place it somewhere on the top dirt layer
    for i, iteration in ipairs(task.iterations) do
        resumable:addMain(string.format("load-up-%d", i), function()
            -- [todo] ❌ need to use provideItems(). issue with that is that we only have 2x buffer barrels in the chunk-storage,
            -- limiting us to only 2x shulkers
            print("[connect] to storage to load:")
            for item, quantity in pairs(iteration.stock) do
                print(string.format(" - %dx %s", quantity, item))
            end

            TurtleApi.requireItemsFromStorage(iteration.stock, true)
            print("[ready] for building")
        end)

        ---@param state BuildChunkPylonState
        resumable:addSimulatableMain(string.format("build-%d", i), function(state)
            print(string.format("[build] %d layers", iteration.layers))

            for item, quantity in pairs(iteration.stock) do
                print(string.format(" - %dx %s", quantity, item))
            end

            local target = TurtleApi.getChunkNorthWest(task.chunkX, state.nextY, task.chunkZ)
            print(string.format("[move] to %d/%d/%d", target.x, target.y, target.z))
            TurtleApi.moveToPoint(target)
            TurtleApi.face(Cardinal.east)

            print("[building] layers...")
            local materialIndex = 1
            local stock = Utils.copy(iteration.stock)
            local layer = 1

            -- [todo] ❌ test that it works even if there are mobs in the way
            while layer <= iteration.layers do
                local material = iteration.materials[materialIndex]

                -- need to go up once because the buildFloor() fn will build below the turtle
                TurtleApi.up()

                -- deepslate can never be built with multiple layers at once due to its different orientations
                if layer + 1 < iteration.layers and stock[material] >= (size * size * 3) and material ~= ItemApi.deepslate then
                    -- we can build 3x layers at once
                    TurtleApi.buildTripleFloor(size, size, material)
                    TurtleApi.left()
                    stock[material] = stock[material] - (size * size * 3)
                    layer = layer + 3
                elseif layer < iteration.layers and stock[material] >= (size * size * 2) and material ~= ItemApi.deepslate then
                    -- we can build 2x layers at once
                    TurtleApi.buildDoubleFloor(size, size, material)
                    TurtleApi.left()
                    stock[material] = stock[material] - (size * size * 2)
                    layer = layer + 2
                else
                    TurtleApi.buildFloor(size, size, material)
                    TurtleApi.right()
                    stock[material] = stock[material] - (size * size)
                    layer = layer + 1
                end

                if stock[material] == 0 then
                    materialIndex = materialIndex + 1
                end
            end

            print("[ready] going home!")
            local localChunkCenter = Vector.create(chunkCenter.x, TurtleApi.getPosition().y, chunkCenter.z)
            TurtleApi.moveToPoint(localChunkCenter)
            print(string.format("[move] to %d/%d/%d", localChunkCenter.x, localChunkCenter.y, localChunkCenter.z))
            TurtleApi.face(Cardinal.south)
            TurtleApi.up(task.storageY - TurtleApi.getPosition().y)
            state.nextY = state.nextY + iteration.layers
        end)
    end

    ---@param state BuildChunkPylonState
    resumable:setFinish(function(state)
        local service = Rpc.nearest(ChunkPylonService)
        service.markPylonBuilt(task.chunkX, task.chunkZ)
        TurtleApi.navigate(task.hubHome)
        TurtleApi.face(task.hubFacing)
        TurtleApi.dumpAllToStorage({[ItemApi.diskDrive] = 1})
    end)

    resumable:run()
end

return BuildChunkPylonWorker
