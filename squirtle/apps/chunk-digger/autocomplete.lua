local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"autorun"}})
shell.setCompletionFunction("squirtle/apps/chunk-digger/app.lua", complete)
shell.setAlias("chunk-digger", "squirtle/apps/chunk-digger/app.lua")
