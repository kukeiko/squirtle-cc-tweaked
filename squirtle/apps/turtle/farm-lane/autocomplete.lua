local completion = require "cc.shell.completion"
local complete = completion.build(nil, {completion.choice, {"turn-left", "turn-right"}})
shell.setCompletionFunction("squirtle/apps/turtle/farm-lane/app.lua", complete)
shell.setAlias("farm-lane", "squirtle/apps/turtle/farm-lane/app.lua")
