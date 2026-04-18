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
local EntitySchema = require "lib.common.entity-schema"
local SearchableList = require "lib.ui.searchable-list"
local EditEntity = require "lib.ui.edit-entity"
local ChunkPylonService = require "lib.building.chunk-pylon-service"

local app = Shell.getApplication(arg)

app:addWindow("Chunk Pylons", function()
    local service = Rpc.nearest(ChunkPylonService)

    local function getOptions()
        local chunkPylons = service.getAll()
        return Utils.map(chunkPylons, function(item)
            ---@type SearchableListOption
            local option = {id = item.id, name = string.format("%d/%d", item.chunkX, item.chunkZ)}

            return option
        end)
    end

    local list = SearchableList.new(getOptions(), "Chunk Pylons", 10, 1, getOptions)

    while true do
        list:run()
    end
end)

app:addWindow("New Pylon", function()
    local service = Rpc.nearest(ChunkPylonService)

    ---@type Vector?
    local position
    ---@type ChunkPylon?
    local chunkPylon

    EventLoop.run(function()
        while true do
            position = Utils.tryGetPosition()

            if position then
                local chunkX, chunkZ = Utils.toChunkXZ(position)
                chunkPylon = service.tryGet(chunkX, chunkZ)
            else
                chunkPylon = nil
            end

            term.clear()
            term.setCursorPos(1, 1)

            if not position then
                print("Position not available")
            elseif not chunkPylon then
                print("<hit enter to create pylon at x/z>")
            else
                print("chunk pylon already exists")
            end

            os.sleep(1)
        end
    end, function()
        while true do
            EventLoop.pullKeys({keys.enter, keys.numPadEnter})
        end
    end)
end)

app:run()
