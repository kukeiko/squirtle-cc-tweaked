local EventLoop = require "event-loop"

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
---@field success boolean
---@field response table|string
---@field type "response"

---@class RpcClient
---@field host string
---@field distance number?

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

---@return table
local function getWirelessModem()
    return peripheral.find("modem", function(name, modem)
        return modem.isWireless()
    end) or error("no wireless modem equipped")
end

---@param name? string
---@return table
local function getModem(name)
    if not name then
        return getWirelessModem()
    else
        return peripheral.wrap(name)
    end
end

---@class Rpc
local Rpc = {}

---@param service Service
---@param modemName? string 
---@param maxDistance? number
---@return { host:string, distance:number }[]
local function findAllHosts(service, modemName, maxDistance)
    local modem = getModem(modemName)
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

    return hosts
end

---@generic T
---@param service T | Service
---@param modem? string
---@param maxDistance? number
---@return (T|RpcClient)?, number?
function Rpc.nearest(service, modem, maxDistance)
    local hosts = findAllHosts(service, modem, maxDistance)

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

---@generic T
---@param service T | Service
---@param modem? string
---@param maxDistance? number
---@return (T|RpcClient)[]
function Rpc.all(service, modem, maxDistance)
    local hosts = findAllHosts(service, modem, maxDistance)
    ---@type RpcClient[]
    local clients = {}

    for i = 1, #hosts do
        table.insert(clients, Rpc.client(service, hosts[i].host))
    end

    return clients
end

---@param service Service
---@param modemName? string
function Rpc.server(service, modemName)
    service.host = os.getComputerLabel()
    local modem = getModem(modemName)
    modem.open(channel)
    print("[host]", service.name, "@", service.host, "using modem", peripheral.getName(modem))

    EventLoop.run(function()
        while true do
            ---@param modem string
            ---@param message RpcRequestPacket|RpcPingPacket
            EventLoop.pull("modem_message", function(_, modem, _, _, message)
                -- todo: make type safe
                if type(message) == "table" and message.type == "request" and message.service == service.name and message.host ==
                    service.host and type(service[message.method]) == "function" then
                    local success, response = pcall(function()
                        return table.pack(service[message.method](table.unpack(message.arguments)))
                    end)

                    ---@type RpcResponsePacket
                    local packet = {callId = message.callId, type = "response", response = response, success = success}
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
    local client = {host = host, distance = nil}
    local modem = getWirelessModem()
    modem.open(channel)

    for k, v in pairs(service) do
        if type(v) == "function" then
            client[k] = function(...)
                local callId = nextCallId()

                ---@type RpcRequestPacket
                local packet = {type = "request", callId = callId, host = host, service = service.name, method = k, arguments = {...}}

                modem.transmit(channel, channel, packet)

                while true do
                    local event = {EventLoop.pull("modem_message")}
                    local message = event[5] --[[@as RpcResponsePacket]]
                    local distance = event[6] --[[@as number|nil]]

                    if type(message) == "table" and message.callId == callId and message.type == "response" then
                        client.distance = distance

                        if message.success then
                            return table.unpack(message.response --[[@as table]] )
                        else
                            error(message.response)
                        end
                    end
                end
            end
        end
    end

    return client
end

return Rpc
