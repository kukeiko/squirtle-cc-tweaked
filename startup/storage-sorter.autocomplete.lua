local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"bottom", "top"}})
shell.setCompletionFunction("apps/storage-sorter.lua", complete)
shell.setAlias("storage-sorter", "apps/storage-sorter.lua")
