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

---@class RpcServer
---@field service Service
---@field open function
---@field close function
---@field getWiredName fun() : string

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

---@param side? string
local function getWiredModem(side)
    return peripheral.find("modem", function(foundSide, modem)
        return not modem.isWireless() and (side == nil or foundSide == side)
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
    elseif modemType == "wired" then
        return getWiredModem() or error("no wired modem found")
    else
        return getWiredModem(modemType) or error(string.format("no wired modem found @ %s", modemType))
    end
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param request? table
local function logClientRequest(method, clientChannel, serverChannel, request)
    local message = string.format("\62 %s %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, request)
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param response? table
local function logClientResponse(method, clientChannel, serverChannel, response)
    local message = string.format("\60 %s %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, response)
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param request? table
local function logServerRequest(method, clientChannel, serverChannel, request)
    local message = string.format("\171 %s %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, request)
end

---@param method string
---@param clientChannel integer
---@param serverChannel integer
---@param response? table
local function logServerResponse(method, clientChannel, serverChannel, response)
    local message = string.format("\187 %s %d/%d", method, clientChannel, serverChannel)
    Logger.log(message, response)
end

---@class Rpc
---@field servers RpcServer[]
local Rpc = {servers = {}}

---@param service Service
---@return DiscoveredServiceHost
local function waitForPong(service)
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
            return discovered
        end
    end
end

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
            table.insert(hosts, waitForPong(service))
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
---@param modemType? "wired" | "wireless"
---@return fun(): T | RpcClient
function Rpc.discover(service, modemType)
    local modem = getModem(modemType)
    local channel = os.getComputerID()
    modem.open(pingChannel)
    modem.open(channel)

    ---@type RpcPingPacket
    local ping = {type = "ping", service = service.name}
    modem.transmit(pingChannel, channel, ping)

    ---@type table<string, true>
    local alreadyDiscovered = {}

    return function()
        while true do
            local discovered = waitForPong(service)

            if not alreadyDiscovered[discovered.host] then
                alreadyDiscovered[discovered.host] = true
                return createClient(service, discovered.host, discovered.distance, discovered.channel)
            end
        end
    end
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
    local localServer = Utils.find(Rpc.servers, function(candidate)
        return candidate.service.name == service.name
    end)

    if localServer then
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

-- [todo] ❌ instead of "string" for "modemType", should be some "Side" type for front, left, etc.
---@param service Service
---@param modemType? "wired" | "wireless" | string
---@return RpcServer
function Rpc.server(service, modemType)
    local modem = getModem(modemType)
    ---@type string
    local host

    if modem.isWireless() then
        host = os.getComputerLabel() or error("can't host a service without a computer label when using a wireless modem")
    else
        host = modem.getNameLocal() or error("the wired modem seems to be inactive")
    end

    local listenChannel = os.getComputerID()
    modem.open(pingChannel)
    modem.open(listenChannel)
    local modemName = peripheral.getName(modem)

    print("[host]", service.name, "@", host, "using modem", peripheral.getName(modem))

    ---@param message RpcRequestPacket|RpcPingPacket
    ---@param distance? number
    local function shouldAcceptMessage(message, distance)
        if type(message) ~= "table" then
            return false
        end

        if service.maxDistance ~= nil and (not distance or distance > service.maxDistance) then
            return false
        end

        if message.host and message.host ~= host then
            return false
        end

        if message.service ~= service.name then
            return false
        end

        return true
    end

    local closeEvent = string.format("rpc-server-close:%s:%d", service.name, nextId())

    ---@type RpcServer
    local this

    ---@type RpcServer
    local server = {
        service = service,
        open = function()
            table.insert(Rpc.servers, this)
            EventLoop.runUntil(closeEvent, function()
                while true do
                    ---@param modemReceived string
                    ---@param message RpcRequestPacket|RpcPingPacket
                    ---@param receivedChannel integer
                    ---@param replyChannel integer
                    ---@param distance? number
                    EventLoop.pull("modem_message", function(_, modemReceived, receivedChannel, replyChannel, message, distance)
                        if modemReceived ~= modemName then
                            return
                        end

                        if not shouldAcceptMessage(message, distance) then
                            return
                        end

                        if message.type == "ping" then
                            logServerRequest("ping", replyChannel, receivedChannel, message)
                            ---@type RpcPongPacket
                            local pong = {type = "pong", host = host, service = service.name}
                            peripheral.call(modemReceived, "transmit", replyChannel, listenChannel, pong)
                            logServerResponse("pong", replyChannel, listenChannel, pong)
                        elseif message.type == "request" and message.host == host and type(service[message.method]) == "function" then
                            logServerRequest(message.method, replyChannel, receivedChannel, message)

                            local success, response = pcall(function()
                                return table.pack(service[message.method](table.unpack(message.arguments)))
                            end)

                            ---@type RpcResponsePacket
                            local packet = {callId = message.callId, type = "response", response = response, success = success}
                            peripheral.call(modemReceived, "transmit", replyChannel, listenChannel, packet)
                            logServerResponse(message.method, replyChannel, receivedChannel, packet)
                        end
                    end)
                end
            end)
        end,
        close = function()
            Utils.remove(Rpc.servers, this)
            EventLoop.queue(closeEvent)
        end,
        getWiredName = function()
            if modem.isWireless() then
                error("modem is not wired")
            end

            return modem.getNameLocal()
        end
    }

    this = server

    return server
end

---@param service Service
---@param modemType? "wired" | "wireless"
function Rpc.host(service, modemType)
    local server = Rpc.server(service, modemType)
    server.open()
end

return Rpc
