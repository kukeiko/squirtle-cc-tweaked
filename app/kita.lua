if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = {"computer", "pocket", "turtle"}}
end

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local ApplicationService = require "lib.system.application-service"
local Shell = require "lib.system.shell"
local duck = require "lib.ui.duck"

-- [todo] ❌ script to install kita on the root server hosting database + applications
-- [todo] ❌ script to install kita using the root server
-- [todo] ❌ script to install via pastebin

---@type string?
local autorun = arg[1]
local app = Shell.getApplication(arg)

if autorun then
    if not Shell.isInstalled(autorun) then
        print(string.format("[install] %s...", autorun))
        local applicationService = Rpc.nearest(ApplicationService)
        Shell.install(autorun, applicationService)
    end

    Shell.addAutorun(autorun)
end

duck({string.format("%s", autorun), "", string.format("[kita %s]", version())})

EventLoop.run(function()
    app:run(true)
end, function()
    if autorun then
        Shell.show(autorun)
    end
end)

term.clear()
term.setCursorPos(1, 1)
