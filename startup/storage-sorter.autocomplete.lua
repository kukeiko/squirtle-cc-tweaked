local completion = require "cc.shell.completion"
local complete = completion.build({completion.choice, {"from-bottom", "from-top"}},
                                  {completion.choice, many = true, {"autorun"}})
shell.setCompletionFunction("apps/storage-sorter.lua", complete)
shell.setAlias("storage-sorter", "apps/storage-sorter.lua")
