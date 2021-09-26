local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"autorun"}})
shell.setCompletionFunction("apps/pipe-activity.lua", complete)
shell.setAlias("pipe-activity", "apps/pipe-activity.lua")
