if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "pocket"}
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local Shell = require "lib.system.shell"
local ShellService = require "lib.system.shell-service"
local TaskService = require "lib.system.task-service"
local EntitySchema = require "lib.common.entity-schema"
local SearchableList = require "lib.ui.searchable-list"
local EditEntity = require "lib.ui.edit-entity"
local ChunkPylonService = require "lib.building.chunk-pylon-service"

local app = Shell.getApplication(arg)

---@param service ChunkPylonService|RpcClient
---@return boolean, ChunkPylon?, integer?, integer?
local function getCurrentChunkPylon(service)
    local position = Utils.tryGetPosition()

    if not position then
        return false
    end

    local chunkX, chunkZ = Utils.toChunkXZ(position)
    local chunkPylon = service.tryGet(chunkX, chunkZ)

    return true, chunkPylon, chunkX, chunkZ
end

app:addWindow("Current Pylon", function(shellWindow)
    local function getTitle()
        local position = Utils.tryGetPosition()

        if not position then
            return "No GPS available"
        end

        local chunkX, chunkZ = Utils.toChunkXZ(position)
        return string.format("Pylon %d/%d", chunkX, chunkZ)
    end

    shellWindow:runWhileVisible(function()
        local service = Rpc.nearest(ChunkPylonService)

        local function getOptions()
            local hasPosition, chunkPylon = getCurrentChunkPylon(service)

            if not hasPosition then
                -- [todo] ❌ somehow add UI to show that GPS is missing
                return {}
            end

            if not chunkPylon then
                ---@type SearchableListOption[]
                local options = {{id = "create-here", name = "Create Here"}}

                return options
            else
                local canUpdateStorageY = service.canUpdateStorageY(chunkPylon.chunkX, chunkPylon.chunkZ)

                ---@type SearchableListOption[]
                local options = {
                    {
                        id = "build-storage",
                        name = "Build Storage",
                        suffix = chunkPylon.isBuildingStorage and "[busy]" or chunkPylon.isStorageBuilt and "[done]" or ""
                    },
                    {
                        id = "dig-chunk",
                        name = "Dig Chunk",
                        suffix = chunkPylon.isDiggingChunk and "[busy]" or chunkPylon.isChunkDugOut and "[done]" or ""
                    },
                    {
                        id = "build-pylon",
                        name = "Build Pylon",
                        suffix = chunkPylon.isRebuildingChunk and "[busy]" or chunkPylon.isPylonBuilt and "[done]" or ""
                    },
                    {id = "empty-storage", name = "Empty Storage"}
                }

                if canUpdateStorageY then
                    ---@type SearchableListOption
                    local updateStorageYOption = {id = "update-storage-y", name = "Update Storage Y"}
                    table.insert(options, updateStorageYOption)
                end

                return options
            end
        end

        local list = SearchableList.new(getOptions(), getTitle(), 30, 3, getOptions)

        EventLoop.waitForAny(function()
            while true do
                list:setTitle(getTitle())
                os.sleep(1)
            end
        end, function()
            while true do
                local selected = list:run()

                if selected then
                    if selected.id == "create-here" then
                        local position = Utils.getPosition()
                        local chunkX, chunkZ = Utils.toChunkXZ(position)
                        -- first layer is the layer the player stands on
                        local storageY = math.floor(position.y - 2)
                        service.create(chunkX, chunkZ, storageY)
                        list:setOptions(getOptions())
                    elseif selected.id == "update-storage-y" then
                        local position = Utils.getPosition()
                        local _, chunkPylon = getCurrentChunkPylon(service)

                        if chunkPylon then
                            service.updateStorageY(chunkPylon.chunkX, chunkPylon.chunkZ, math.floor(position.y - 2))
                            print("Storage Y updated!")
                            os.sleep(1)
                        end
                    elseif selected.id == "build-storage" then
                        local _, chunkPylon = getCurrentChunkPylon(service)

                        if chunkPylon and not chunkPylon.isBuildingStorage and not chunkPylon.isStorageBuilt then
                            service.buildStorage(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
                        end
                    elseif selected.id == "dig-chunk" then
                        local _, chunkPylon = getCurrentChunkPylon(service)

                        if chunkPylon and not chunkPylon.isDiggingChunk and not chunkPylon.isChunkDugOut then
                            service.digChunk(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
                        end
                    elseif selected.id == "build-pylon" then
                        local _, chunkPylon = getCurrentChunkPylon(service)

                        -- [todo] ❌ implement choosing between desert or default materials
                        if chunkPylon and not chunkPylon.isRebuildingChunk and not chunkPylon.isPylonBuilt then
                            service.buildPylon(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
                        end
                    elseif selected.id == "empty-storage" then
                        local taskService = Rpc.nearest(TaskService)
                        local _, chunkPylon = getCurrentChunkPylon(service)

                        if chunkPylon then
                            taskService.emptyChunkStorage({
                                issuedBy = os.getComputerLabel(),
                                chunkX = chunkPylon.chunkX,
                                chunkZ = chunkPylon.chunkZ,
                                storageY = chunkPylon.storageY,
                                autoDelete = true,
                                skipAwait = true,
                                label = chunkPylon.id
                            })
                        end
                    end
                end
            end
        end)
    end)
end)

app:addWindow("Chunk Pylons", function()
    local service = Rpc.nearest(ChunkPylonService)

    local function getOptions()
        local chunkPylons = service.getAll()
        return Utils.map(chunkPylons, function(item)
            ---@type SearchableListOption
            local option = {id = item.id, name = string.format("%d/%d", item.chunkX, item.chunkZ)}

            if item.isRebuildingChunk then
                -- [todo] ❌ move progress calculation to ChunkPylonService
                local totalLayers = (item.storageY - 1) - (-60)
                local layersBuilt = item.lastBuiltY - (-60)
                local progress = math.floor((layersBuilt / totalLayers) * 100)
                option.suffix = string.format("%d%%", progress)
            end

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Chunk Pylons", 10, 1, getOptions)

    while true do
        list:run()
    end
end)

app:run()
