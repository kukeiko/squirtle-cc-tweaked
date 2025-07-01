local Utils = require "lib.tools.utils"
local LoggingContext = require "lib.tools.logging-context"
local nextId = require "lib.tools.next-id"

-- [todo] ❌ implement EventLoop.configure() to set a different context to categorise log messages
local defaultContext = LoggingContext.new("global")
local maxLogs = 512

---@class Logger
local Logger = {context = defaultContext, messages = {}}

---
---@class LogMessage
---@field id number
---@field level "log" | "error" | "warn"
---@field context string
---@field message string
---@field timestamp string
---@field data? table
---

---@param level "log" | "error" | "warn"
---@param message string
---@param data? table
local function addMessage(level, message, data)
    ---@type LogMessage
    local logMessage = {
        id = nextId(),
        level = level,
        context = Logger.context:getName(),
        message = message,
        timestamp = Utils.getTime24(),
        data = data
    }
    table.insert(Logger.messages, logMessage)

    if #Logger.messages >= maxLogs then
        ---@type LogMessage[]
        local messages = {}

        for i = math.ceil(maxLogs / 2), #Logger.messages do
            table.insert(messages, Logger.messages[i])
        end

        Logger.messages = messages
    end

    os.queueEvent("logger:message", logMessage)
end

---@return LogMessage
function Logger.pullLoggedMessage()
    local _, message = os.pullEvent("logger:message")

    return message
end

---@param context LoggingContext
function Logger.setContext(context)
    local original = Logger.context
    Logger.context = context

    return function()
        Logger.context = original
    end
end

---@param message string
---@param data? table
function Logger.log(message, data)
    addMessage("log", message, data)
end

---@param message string
function Logger.error(message)
    addMessage("error", message)
end

---@param message string
function Logger.warn(message)
    addMessage("warn", message)
end

---@return LogMessage[]
function Logger.getMessages()
    return Utils.copy(Logger.messages)
end

return Logger
