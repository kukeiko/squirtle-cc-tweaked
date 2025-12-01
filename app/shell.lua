if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = "turtle"}
end

local Shell = require "lib.system.shell"
local appsWindow = require "lib.system.windows.apps-window"
local updateAppsWindow = require "lib.system.windows.update-apps-window"
local installAppsWindow = require "lib.system.windows.install-apps-window"

Shell:addWindow("Apps", appsWindow)
Shell:addWindow("Update", updateAppsWindow)
Shell:addWindow("Install", installAppsWindow)
Shell:run()
