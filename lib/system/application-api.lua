local Utils = require "lib.tools.utils"

---@class ApplicationApi
local ApplicationApi = {}

---@type table<string, string>
local versions = {}

---@param path string
local function getAppVersion(path)
    if not versions[path] then
        ---@type ApplicationMetadata
        local metadata = dofile(path)
        versions[path] = metadata.version
    end

    return versions[path]
end

---@param folder string
---@return string[]
local function getFiles(folder)
    ---@type string[]
    local files = {}

    for _, name in ipairs(fs.list(folder)) do
        local path = fs.combine(folder, name)

        if fs.isDir(path) then
            files = Utils.concat(files, getFiles(path))
        else
            table.insert(files, path)
        end
    end

    return files
end

---@param folder string
---@param filter? string[]
---@param withContent? boolean
---@param version? string
---@return Application[]
function ApplicationApi.readApps(folder, filter, withContent, version)
    if not fs.isDir(folder) then
        return {}
    end

    withContent = withContent or false

    ---@type string[]
    local files = getFiles(folder)

    if filter and #filter > 0 then
        files = Utils.filter(files, function(file)
            return Utils.contains(filter, string.gsub(fs.getName(file), ".lua", ""))
        end)
    end

    return Utils.map(files, function(path)
        local appVersion = version or getAppVersion(path)

        ---@type Application
        local app = {name = string.gsub(fs.getName(path), ".lua", ""), version = appVersion, path = path}

        if withContent then
            local file = fs.open(path, "r")
            app.content = file.readAll()
            file.close()
        end

        return app
    end)
end

---@param folder string
---@param application Application
function ApplicationApi.writeApp(folder, application)
    local path = fs.combine(folder, application.name)
    local file = fs.open(path, "w")
    file.write(application.content or "")
    file.close()
    versions[path] = nil
end

return ApplicationApi
