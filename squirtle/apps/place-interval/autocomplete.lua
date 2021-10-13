local completion = require "cc.shell.completion"
local complete = completion.build(nil, {completion.choice, {"forward", "up", "down"}})
shell.setCompletionFunction("squirtle/apps/place-interval/app.lua", complete)
shell.setAlias("place-interval", "squirtle/apps/place-interval/app.lua")
