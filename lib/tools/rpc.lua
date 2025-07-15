local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local Logger = require "lib.tools.logger"
local nextId = require "lib.tools.next-id"

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
---@field distance number
---@field channel integer
---@field ping fun() : boolean

---@class DiscoveredServiceHost
---@field host string
---@field distance integer?
---@field channel integer

---@class Service
---@field name string
---@field host string?
---@field maxDistance integer?

local pingChannel = 0
local pingTimeout = 0.25

---@return string
local function nextCallId()
    return tostring(string.format("%s:%d", os.getComputerLabel(), nextId()))
end

---@return table?
local function getWirelessModem()
    return peripheral.find("modem", function(_, modem)
        return modem.isWireless()
    end)
end

local function getWiredModem()
    return peripheral.find("modem", function(_, modem)
        return not modem.isWireless()
    end)
end

---@param modemType? "wired" | "wireless"
---@return table
local function getModem(modemType)
    if not modemType then
        local wirelessModem = getWirelessModem()

        if not wirelessModem then
            return peripheral.find("modem") or error("no modem found")
        end

        return wirelessModem
    elseif modemType == "wireless" then
        return getWirelessModem() or error("no wireless modem found")
    else
        return getWiredModem() or error("no wired modem found")
    end
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param request? table
local function logClientRequest(method, clientChannel, serverChannel, request)
    local message = string.format("[c:req] %s %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, request)
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param response? table
local function logClientResponse(method, clientChannel, serverChannel, response)
    local message = string.format("[c:res] %s %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, response)
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param request? table
local function logServerRequest(method, clientChannel, serverChannel, request)
    local message = string.format("[s:req] %s, %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, request)
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param response? table
local function logServerResponse(method, clientChannel, serverChannel, response)
    local message = string.format("[s:res] %s, %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, response)
end

---@class Rpc
local Rpc = {}

---@param service Service
---@param timeout number?
---@param modemType? "wired" | "wireless"
---@return DiscoveredServiceHost[]
local function findAllHosts(service, timeout, modemType)
    local modem = getModem(modemType)
    local channel = os.getComputerID()
    modem.open(pingChannel)
    modem.open(channel)

    ---@type DiscoveredServiceHost[]
    local hosts = {}

    EventLoop.runTimed(timeout or pingTimeout, function()
        ---@type RpcPingPacket
        local ping = {type = "ping", service = service.name}
        modem.transmit(pingChannel, channel, ping)

        while true do
            local event = table.pack(EventLoop.pull("modem_message"))
            ---@type integer
            local replyChannel = event[4]
            ---@type RpcPongPacket
            local message = event[5]
            ---@type integer
            local distance = event[6]

            if type(message) == "table" and message.type == "pong" and message.service == service.name then
                ---@type DiscoveredServiceHost
                local discovered = {host = message.host, distance = distance, channel = replyChannel}
                table.insert(hosts, discovered)
            end
        end
    end)

    return hosts
end

---@generic T
---@param service T | Service
---@param host string
---@param distance number
---@param channel? number
---@param modemType? "wired" | "wireless"
---@return T|RpcClient
local function createClient(service, host, distance, channel, modemType)
    local modem = getModem(modemType)
    local clientChannel = os.getComputerID()
    modem.open(pingChannel)
    modem.open(clientChannel)

    ---@type RpcClient
    local client = {
        host = host,
        distance = distance,
        channel = channel or pingChannel,
        ping = function()
            return true
        end
    }

    client.ping = function()
        return EventLoop.runTimed(pingTimeout, function()
            ---@type RpcPingPacket
            local ping = {type = "ping", service = service.name, host = host}
            modem.transmit(client.channel, clientChannel, ping)

            while true do
                local event = table.pack(EventLoop.pull("modem_message"))
                ---@type integer
                local replyChannel = event[4]
                ---@type RpcPongPacket
                local message = event[5]
                ---@type number|nil
                local distance = event[6]

                if type(message) == "table" and message.type == "pong" and message.service == service.name and message.host == host then
                    client.distance = distance or 0
                    client.channel = replyChannel
                    break
                end
            end
        end)
    end

    setmetatable(client, {
        __index = function(_, k)
            return function(...)
                local callId = nextCallId()

                ---@type RpcRequestPacket
                local packet = {type = "request", callId = callId, host = host, service = service.name, method = k, arguments = {...}}
                logClientRequest(k, clientChannel, client.channel, packet)
                modem.transmit(client.channel, clientChannel, packet)

                while true do
                    local event = {EventLoop.pull("modem_message")}
                    ---@type integer
                    local replyChannel = event[4]
                    ---@type RpcResponsePacket
                    local message = event[5]
                    ---@type number?
                    local distance = event[6]

                    if type(message) == "table" and message.callId == callId and message.type == "response" then
                        logClientResponse(k, clientChannel, client.channel, message)
                        client.distance = distance or 0
                        client.channel = replyChannel

                        if message.success then
                            return table.unpack(message.response --[[@as table]] )
                        else
                            error(message.response)
                        end
                    end
                end
            end
        end
    })

    return client
end

---@generic T
---@param service T | Service
---@return T|RpcClient
local function createLocalHostClient(service)
    ---@type RpcClient
    local client = {
        host = os.getComputerLabel(),
        distance = 0,
        channel = 0,
        ping = function()
            return true
        end
    }

    setmetatable(client, {__index = service})

    return client
end

---@generic T
---@param service T | Service
---@param timeout? number
---@param modemType? "wired" | "wireless"
---@return (T|RpcClient)?
function Rpc.tryNearest(service, timeout, modemType)
    if os.getComputerLabel() ~= nil and service.host == os.getComputerLabel() then
        return createLocalHostClient(service)
    end

    ---@type DiscoveredServiceHost?
    local best = nil

    EventLoop.runTimed(timeout, function()
        while not best do
            local hosts = findAllHosts(service, nil, modemType)

            for i = 1, #hosts do
                if best == nil or hosts[i].distance < best.distance then
                    best = hosts[i]
                end
            end
        end
    end)

    if best then
        return createClient(service, best.host, best.distance, best.channel, modemType)
    end
end

---@generic T
---@param service T | Service
---@param timeout? number
---@param modemType? "wired" | "wireless"
---@return (T|RpcClient)
function Rpc.nearest(service, timeout, modemType)
    local nearest = Rpc.tryNearest(service, timeout, modemType)

    if not nearest then
        error(string.format("no %s service found", service.name))
    end

    return nearest
end

---@generic T
---@param service T | Service
---@param timeout number?
---@return (T|RpcClient)[]
function Rpc.all(service, timeout)
    local hosts = findAllHosts(service, timeout)
    ---@type RpcClient[]
    local clients = {}

    for i = 1, #hosts do
        table.insert(clients, createClient(service, hosts[i].host, hosts[i].distance, hosts[i].channel))
    end

    return clients
end

---@param service Service
---@param modemType? "wired" | "wireless"
function Rpc.host(service, modemType)
    local label = os.getComputerLabel()

    if not label then
        error("can't host a service without a label")
    end

    local modem = getModem(modemType)
    service.host = modem.isWireless() and label or modem.getNameLocal()
    local listenChannel = os.getComputerID()
    modem.open(pingChannel)
    modem.open(listenChannel)

    print("[host]", service.name, "@", service.host, "using modem", peripheral.getName(modem))

    ---@param message RpcRequestPacket|RpcPingPacket
    ---@param distance? number
    local function shouldAcceptMessage(message, distance)
        if type(message) ~= "table" then
            return false
        end

        if service.maxDistance ~= nil and (not distance or distance > service.maxDistance) then
            return false
        end

        if message.host and message.host ~= service.host then
            return false
        end

        if message.service ~= service.name then
            return false
        end

        return true
    end

    EventLoop.run(function()
        while true do
            ---@param modem string
            ---@param message RpcRequestPacket|RpcPingPacket
            ---@param receivedChannel integer
            ---@param replyChannel integer
            ---@param distance? number
            EventLoop.pull("modem_message", function(_, modem, receivedChannel, replyChannel, message, distance)
                if not shouldAcceptMessage(message, distance) then
                    return
                end

                if message.type == "ping" then
                    logServerRequest("ping", replyChannel, receivedChannel, message)
                    ---@type RpcPongPacket
                    local pong = {type = "pong", host = service.host, service = service.name}
                    peripheral.call(modem, "transmit", replyChannel, listenChannel, pong)
                    logServerResponse("pong", replyChannel, listenChannel, pong)
                elseif message.type == "request" and message.host == service.host and type(service[message.method]) == "function" then
                    logServerRequest(message.method, replyChannel, receivedChannel, message)

                    local success, response = pcall(function()
                        return table.pack(service[message.method](table.unpack(message.arguments)))
                    end)

                    ---@type RpcResponsePacket
                    local packet = {callId = message.callId, type = "response", response = response, success = success}
                    peripheral.call(modem, "transmit", replyChannel, listenChannel, packet)
                    logServerResponse(message.method, replyChannel, receivedChannel, packet)
                end
            end)
        end
    end)
end

---@generic T
---@param service T | Service
---@param host string
---@param timeout? number
---@param modemType? "wired" | "wireless"
---@return T|RpcClient
function Rpc.connect(service, host, timeout, modemType)
    local client = createClient(service, host, 0, nil, modemType)

    if not EventLoop.runTimed(timeout, function()
        while not client.ping() do
        end
    end) then
        error(string.format("could not connect to %s @ %s", service.name, host))
    end

    return client
end

return Rpc
