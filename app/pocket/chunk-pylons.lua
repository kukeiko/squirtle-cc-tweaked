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
local SearchableList = require "lib.ui.searchable-list"
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

---@param service ChunkPylonService|RpcClient
---@param option SearchableListOption
local function runOption(service, option)
    if option.id == "create-here" then
        local position = Utils.getPosition()
        local chunkX, chunkZ = Utils.toChunkXZ(position)
        -- first layer is the layer the player stands on
        local storageY = math.floor(position.y - 2)
        service.create(chunkX, chunkZ, storageY)

        return
    end

    local _, chunkPylon = getCurrentChunkPylon(service)

    if not chunkPylon then
        return
    end

    if option.id == "update-storage-y" then
        local position = Utils.getPosition()

        local newStorageY = math.floor(position.y - 2)
        service.updateStorageY(chunkPylon.chunkX, chunkPylon.chunkZ, newStorageY)
        print(string.format("Storage Y updated to %d!", newStorageY))
        os.sleep(1)
    elseif option.id == "build-storage" then
        if chunkPylon.isBuildingStorage then
            return
        end

        if chunkPylon.isStorageBuilt and not Utils.confirm("Already built - build again?") then
            return
        end

        service.buildStorage(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
    elseif option.id == "dig-chunk" then
        if chunkPylon.isDiggingChunk then
            return
        end

        if chunkPylon.isChunkDugOut and not Utils.confirm("Already dug out - dig again?") then
            return
        end

        service.digChunk(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
    elseif option.id == "build-pylon" then
        if chunkPylon.isRebuildingChunk then
            return
        end

        if chunkPylon.isPylonBuilt and not Utils.confirm("Already built - build again?") then
            return
        end

        -- [todo] ❌ implement choosing between desert or default materials
        service.buildPylon(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
    elseif option.id == "empty-storage" then
        if chunkPylon.isEmptyingStorage then
            return
        end

        if chunkPylon.isStorageEmpty and not Utils.confirm("Already emptied out - empty out again?") then
            return
        end

        service.emptyStorage(os.getComputerLabel(), chunkPylon.chunkX, chunkPylon.chunkZ)
    end
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

            --- [todo] ❌ add info of current last built/dug y
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
                {
                    id = "empty-storage",
                    name = "Empty Storage",
                    suffix = chunkPylon.isEmptyingStorage and "[busy]" or chunkPylon.isStorageEmpty and "[done]" or ""
                }
            }

            if canUpdateStorageY then
                ---@type SearchableListOption
                local updateStorageYOption = {id = "update-storage-y", name = "Update Storage Y"}
                table.insert(options, updateStorageYOption)
            end

            if chunkPylon.lastBuiltY then
                ---@type SearchableListOption
                local lastBuiltY = {id = "last-built-y", name = "Last Built Y", suffix = tostring(chunkPylon.lastBuiltY)}
                table.insert(options, lastBuiltY)
            end

            if chunkPylon.lastDugY then
                ---@type SearchableListOption
                local lastDugY = {id = "last-dug-y", name = "Last Dug Y", suffix = tostring(chunkPylon.lastDugY)}
                table.insert(options, lastDugY)
            end

            return options
        end
    end

    local list = SearchableList.new(getOptions(), getTitle(), 30, 1, getOptions)

    shellWindow:runWhileVisible(function()
        EventLoop.waitForAny(function()
            while true do
                -- [todo] ❌ just like with options refresher, add support to searchable list for a title refresher
                list:setTitle(getTitle())
                os.sleep(1)
            end
        end, function()
            while true do
                local selected = list:run()

                if selected then
                    runOption(service, selected)
                end
            end
        end)
    end)
end)

app:addWindow("Chunk Pylons", function(shellWindow)
    local service = Rpc.nearest(ChunkPylonService)

    local function getOptions()
        local chunkPylons = service.getAll()

        return Utils.map(chunkPylons, function(item)
            ---@type SearchableListOption
            local option = {id = item.id, name = string.format("%d/%d", item.chunkX, item.chunkZ)}

            if item.isRebuildingChunk and item.lastBuiltY then
                -- [todo] ❌ move progress calculation to ChunkPylonService
                local totalLayers = (item.storageY - 1) - (-60)
                local layersBuilt = item.lastBuiltY - (-60)
                local progress = math.floor((layersBuilt / totalLayers) * 100)
                option.suffix = string.format("%d%%", progress)
            end

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Chunk Pylons", 10, 3, getOptions)

    shellWindow:runWhileVisible(function()
        list:run()
    end)
end)

app:run()
