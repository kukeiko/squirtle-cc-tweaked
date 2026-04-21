local EventLoop = require "lib.tools.event-loop"
local EditEntity = require "lib.ui.edit-entity"

---@param shellWindow ShellWindow
return function(shellWindow)
    local editSettings = EditEntity.new("Change Settings")
    editSettings:addString("rpcHub", "RPC Hub", {optional = true})

    EventLoop.run(function()
        while true do
            local nextSettings = editSettings:run(shellWindow:getShell():getSettings())

            if nextSettings then
                shellWindow:getShell():saveSettings(nextSettings)
                shellWindow:clear()
                print("Settings Saved!")
                os.sleep(1)
            end
        end
    end)
end
