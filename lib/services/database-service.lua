local DatabaseApi = require "lib.apis.database-api"

---@class DatabaseService : Service, DatabaseApi
local DatabaseService = {name = "database"}
setmetatable(DatabaseService, {__index = DatabaseApi})

return DatabaseService
