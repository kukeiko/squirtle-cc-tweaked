local EventLoop = require "event-loop"

---@return table
local function getWirelessModem()
    return peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end) or error("no wireless modem equipped")
end

---@class RpcPingPacket
---@field type "ping"
---@field service string
---@field host? string

---@class RpcPongPacket
---@field type "pong"
---@field service string
---@field host string

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

---@class RpcClient
---@field host string

---@class Service
---@field host string
---@field name string

local callId = 0
local channel = 64

---@return string
local function nextCallId()
    callId = callId + 1

    return tostring(callId)
end

---@class Rpc
local Rpc = {}

---@generic T
---@param service T | Service
---@param maxDistance? number
---@return (T|RpcClient)?, number?
function Rpc.nearest(service, maxDistance)
    local modem = getWirelessModem()
    modem.open(channel)

    ---@type { host:string, distance:number }[]
    local hosts = {}

    parallel.waitForAny(function()
        os.sleep(0.25)
    end, function()
        ---@type RpcPingPacket
        local ping = {type = "ping", service = service.name}
        modem.transmit(channel, channel, ping)

        while true do
            local event = table.pack(EventLoop.pull("modem_message"))
            local message = event[5]
            local distance = event[6]

            if type(message) == "table" and message.type == "pong" and message.service == service.name then
                if maxDistance then
                    if distance <= maxDistance then
                        table.insert(hosts, {host = message.host, distance = distance})
                    end
                else
                    table.insert(hosts, {host = message.host, distance = distance})
                end
            end
        end
    end)

    ---@type { host:string, distance:number }?
    local best = nil

    for i = 1, #hosts do
        if best == nil or hosts[i].distance < best.distance then
            best = hosts[i]
        end
    end
    
    if best then
        return Rpc.client(service, best.host), best.distance
    end
end

---@param service Service
function Rpc.server(service)
    local modem = getWirelessModem()
    modem.open(channel)

    EventLoop.run(function()
        while true do
            EventLoop.pull("modem_message", function(_, modem, _, _, message)
                -- todo: make type safe
                if type(message) == "table" and message.type == "request" and message.service == service.name and
                    message.host == service.host and type(service[message.method]) == "function" then
                    local response = table.pack(service[message.method](table.unpack(message.arguments)))
                    ---@type RpcResponsePacket
                    local packet = {callId = message.callId, type = "response", response = response}
                    peripheral.call(modem, "transmit", channel, channel, packet)
                elseif type(message) == "table" and message.type == "ping" and message.service == service.name then
                    ---@type RpcPongPacket
                    local pong = {type = "pong", host = service.host, service = service.name}
                    peripheral.call(modem, "transmit", channel, channel, pong)
                end
            end)
        end
    end)
end

---@generic T
---@param service T | Service
---@param host string
---@return T|RpcClient
function Rpc.client(service, host)
    ---@type RpcClient
    local client = {host = host}
    local modem = getWirelessModem()
    modem.open(channel)

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

                modem.transmit(channel, channel, packet)

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
