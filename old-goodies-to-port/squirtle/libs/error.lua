local Error = {generic = 0, noTool = 1, nothingToDig = 2}
local names = {}

for k, v in pairs(Error) do
    names[v] = k
end

local nativeErrorsMapping = {
    ["No tool to dig with"] = Error.noTool,
    ["Nothing to dig here"] = Error.nothingToDig
}

---@param error integer
function Error.getName(error)
    return names[error] or tostring(error);
end

---@param message string
---@return integer
function Error.fromNativeMessage(message)
    return nativeErrorsMapping[message] or Error.generic
end

return Error
