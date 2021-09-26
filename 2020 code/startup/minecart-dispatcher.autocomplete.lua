local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"autorun"}})
shell.setCompletionFunction("apps/minecart-dispatcher.lua", complete)
shell.setAlias("minecart-dispatcher", "apps/minecart-dispatcher.lua")
