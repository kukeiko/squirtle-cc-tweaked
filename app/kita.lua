if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    ---@type ApplicationMetadata
    return {version = version(), platform = {"computer", "pocket", "turtle"}}
end

term.clear()
term.setCursorPos(1, 1)

local EventLoop = require "lib.tools.event-loop"
local Rpc = require "lib.tools.rpc"
local ApplicationService = require "lib.system.application-service"
local Shell = require "lib.system.shell"
local duck = require "lib.ui.duck"

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

if Shell.getSettings().autoUpdate then
    term.clear()
    term.setCursorPos(1, 1)
    print("[auto-update] checking for updates...")
    local applicationService = Rpc.tryNearest(ApplicationService, 1)

    if not applicationService then
        print("[auto-update] no application service reachable, skipping updates")
        os.sleep(1)
    else
        local didUpdate = Shell.update(applicationService)

        if didUpdate then
            print("[reboot] in 3s...")
            os.sleep(3)
            os.reboot()
        end
    end
end

if autorun then
    duck({string.format("%s %s", autorun, app.metadata.version), "", string.format("[kita %s]", version())})
else
    duck({string.format("[kita %s]", version())})
end

EventLoop.run(function()
    app:run(true)
end, function()
    if autorun then
        Shell.show(autorun)
    end
end)

term.clear()
term.setCursorPos(1, 1)
