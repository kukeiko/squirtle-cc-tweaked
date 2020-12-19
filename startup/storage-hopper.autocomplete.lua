local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"from-left", "from-right"}}, {completion.choice, {"run-on-startup"}})
shell.setCompletionFunction("apps/storage-hopper.lua", complete)
shell.setAlias("storage-hopper", "apps/storage-hopper.lua")
