local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"autorun", ""}})
shell.setCompletionFunction("squirtle/apps/turtle/farm-tiles/app.lua", complete)
shell.setAlias("farm-tiles", "squirtle/apps/turtle/farm-tiles/app.lua")
