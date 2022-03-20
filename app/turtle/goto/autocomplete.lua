local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"autorun", ""}})
shell.setCompletionFunction("squirtle/apps/turtle/goto/app.lua", complete)
shell.setAlias("goto", "squirtle/apps/turtle/goto/app.lua")
