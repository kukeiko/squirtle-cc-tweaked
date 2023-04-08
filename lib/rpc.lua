local EventLoop = require "event-loop"

---@return table
local function getWirelessModem()
    return peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end) or error("no wireless modem equipped")
end

---@class RpcRequestPacket
---@field callId string
---@field service string
---@field method string
---@field arguments table
---@field host string
---@field type "request"

---@class RpcResponsePacket
---@field callId string
---@field response table
---@field type "response"

---@class Service
---@field name string

local callId = 0

---@return string
local function nextCallId()
    callId = callId + 1

    return tostring(callId)
end

---@class Rpc
local Rpc = {}

---@param service Service
---@param host string
function Rpc.server(service, host)
    local modem = getWirelessModem()
    modem.open(64)

    EventLoop.run(function()
        while true do
            EventLoop.pull("modem_message", function(_, modem, _, _, message)
                -- todo: make type safe
                if type(message) == "table" and message.type == "request" and message.service == service.name and
                    message.host == host and type(service[message.method]) == "function" then
                    local response = table.pack(service[message.method](table.unpack(message.arguments)))
                    ---@type RpcResponsePacket
                    local packet = {callId = message.callId, type = "response", response = response}
                    peripheral.call(modem, "transmit", 64, 64, packet)
                end
            end)
        end
    end)
end

---@generic T
---@param service T | Service
---@param host string
---@return T
function Rpc.client(service, host)
    local client = {}
    local modem = getWirelessModem()
    modem.open(64)

    for k, v in pairs(service) do
        if type(v) == "function" then
            client[k] = function(...)
                local callId = nextCallId()

                ---@type RpcRequestPacket
                local packet = {
                    type = "request",
                    callId = callId,
                    host = host,
                    service = service.name,
                    method = k,
                    arguments = {...}
                }

                modem.transmit(64, 64, packet)

                while true do
                    local event = {EventLoop.pull("modem_message")}
                    local message = event[5]

                    -- todo: make type safe
                    if type(message) == "table" and message.callId == callId and message.type == "response" then
                        return table.unpack(message.response)
                    end
                end
            end
        end
    end

    return client
end

return Rpc
