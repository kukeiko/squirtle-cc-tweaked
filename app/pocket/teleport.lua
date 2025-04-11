if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local SearchableList = require "lib.ui.searchable-list"
local TeleportService = require "lib.systems.teleport-service"

---@return SearchableListOption[]
local function getListOptions()
    local teleports = Utils.filter(Rpc.all(TeleportService), function(teleport)
        return teleport.hasPdaId(os.getComputerID())
    end)

    local options = Utils.map(teleports, function(teleport)
        ---@type SearchableListOption
        local option = {id = teleport.host, name = teleport.host, suffix = tostring(math.ceil(teleport.distance or 0))}

        return option
    end)

    return options
end

---@param host string
local function teleport(host)
    local station = Rpc.connect(TeleportService, host, 1)

    if not station then
        print(string.format("station %s not reachable", host))
        os.sleep(1)
        return
    end

    station.activate(os.getComputerID())
    os.sleep(1)
end

EventLoop.run(function()
    while true do
        local list = SearchableList.new(getListOptions(), "Teleport", nil, 3, getListOptions)
        local selected = list:run()

        if selected then
            teleport(selected.id)
        end
    end
end)

term.clear()
term.setCursorPos(1, 1)
