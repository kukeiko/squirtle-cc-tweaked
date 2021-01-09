local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"autorun"}})
shell.setCompletionFunction("apps/item-transporter.lua", complete)
shell.setAlias("item-transporter", "apps/item-transporter.lua")