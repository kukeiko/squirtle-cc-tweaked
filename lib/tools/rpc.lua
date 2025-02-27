local EventLoop = require "lib.tools.event-loop"

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
---@field ping fun() : boolean

---@class Service
---@field host string
---@field name string
---@field maxDistance? integer

local callId = 0
local channel = 64
local pingTimeout = 0.25

---@return string
local function nextCallId()
    callId = callId + 1

    return tostring(string.format("%s:%d", os.getComputerLabel(), callId))
end

---@return table
local function getWirelessModem()
    return peripheral.find("modem", function(_, modem)
        return modem.isWireless()
    end) or error("no wireless modem equipped")
end

---@param name? string
---@return table
local function getModem(name)
    if not name then
        return getWirelessModem()
    else
        local modem = peripheral.wrap(name)

        if not modem then
            error(string.format("peripheral %s not found", name))
        end

        return modem
    end
end

---@class Rpc
local Rpc = {}

---@param service Service
---@return { host:string, distance:number }[]
local function findAllHosts(service)
    local modem = getModem()
    modem.open(channel)

    ---@type { host:string, distance:number }[]
    local hosts = {}

    EventLoop.runTimed(pingTimeout, function()
        ---@type RpcPingPacket
        local ping = {type = "ping", service = service.name}
        modem.transmit(channel, channel, ping)

        while true do
            local event = table.pack(EventLoop.pull("modem_message"))
            ---@type RpcPongPacket
            local message = event[5]
            ---@type integer
            local distance = event[6]

            if type(message) == "table" and message.type == "pong" and message.service == service.name then
                table.insert(hosts, {host = message.host, distance = distance})
            end
        end
    end)

    return hosts
end

---@generic T
---@param service T | Service
---@param host string
---@param distance number
---@return T|RpcClient
local function createClient(service, host, distance)
    local modem = getWirelessModem()
    -- [todo] consider using computer id instead (to prevent inspecting messages of other computers)
    modem.open(channel)

    ---@type RpcClient
    local client = {
        host = host,
        distance = distance,
        ping = function()
            return true
        end
    }

    client.ping = function()
        return EventLoop.runTimed(pingTimeout, function()
            ---@type RpcPingPacket
            local ping = {type = "ping", service = service.name, host = host}
            modem.transmit(channel, channel, ping)

            while true do
                local event = table.pack(EventLoop.pull("modem_message"))
                ---@type RpcPongPacket
                local message = event[5]
                ---@type number|nil
                local distance = event[6]

                if type(message) == "table" and message.type == "pong" and message.service == service.name and message.host == host then
                    client.distance = distance or 0
                    break
                end
            end
        end)
    end

    for k, v in pairs(service) do
        if type(v) == "function" then
            -- [todo] periodically send ping messages that, if fail, cause the rpc call to error out
            -- [todo] i would love that a request works even if the host rebooted
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
                        client.distance = distance or 0

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

---@generic T
---@param service T | Service
---@return T|RpcClient
local function createLocalHostClient(service)
    ---@type RpcClient
    local client = {
        host = os.getComputerLabel(),
        distance = 0,
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
---@return (T|RpcClient)?
function Rpc.tryNearest(service, timeout)
    if os.getComputerLabel() ~= nil and service.host == os.getComputerLabel() then
        return createLocalHostClient(service)
    end

    ---@type { host:string, distance:number }?
    local best = nil

    EventLoop.runTimed(timeout, function()
        while not best do
            local hosts = findAllHosts(service)

            for i = 1, #hosts do
                if best == nil or hosts[i].distance < best.distance then
                    best = hosts[i]
                end
            end
        end
    end)

    if best then
        return createClient(service, best.host, best.distance)
    end
end

---@generic T
---@param service T | Service
---@param timeout? number
---@return (T|RpcClient)
function Rpc.nearest(service, timeout)
    local nearest = Rpc.tryNearest(service, timeout)

    if not nearest then
        error(string.format("no %s service found", service.name))
    end

    return nearest
end

---@generic T
---@param service T | Service
---@return (T|RpcClient)[]
function Rpc.all(service)
    local hosts = findAllHosts(service)
    ---@type RpcClient[]
    local clients = {}

    for i = 1, #hosts do
        table.insert(clients, createClient(service, hosts[i].host, hosts[i].distance))
    end

    return clients
end

---@param service Service
---@param modemName? string
function Rpc.host(service, modemName)
    local label = os.getComputerLabel()

    if not label then
        error("can't host a service without a label")
    end

    service.host = label
    local modem = getModem(modemName)
    modem.open(channel)
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
            ---@param distance? number
            EventLoop.pull("modem_message", function(_, modem, _, _, message, distance)
                if not shouldAcceptMessage(message, distance) then
                    return
                end

                if message.type == "ping" then
                    ---@type RpcPongPacket
                    local pong = {type = "pong", host = service.host, service = service.name}
                    peripheral.call(modem, "transmit", channel, channel, pong)
                elseif message.type == "request" and message.host == service.host and type(service[message.method]) == "function" then
                    local success, response = pcall(function()
                        return table.pack(service[message.method](table.unpack(message.arguments)))
                    end)

                    ---@type RpcResponsePacket
                    local packet = {callId = message.callId, type = "response", response = response, success = success}
                    peripheral.call(modem, "transmit", channel, channel, packet)
                end
            end)
        end
    end)
end

---@generic T
---@param service T | Service
---@param host string
---@param timeout? number
---@return T|RpcClient
function Rpc.connect(service, host, timeout)
    local client = createClient(service, host, 0)

    if not EventLoop.runTimed(timeout, function()
        while not client.ping() do
        end
    end) then
        error(string.format("could not connect to %s @ %s", service.name, host))
    end

    return client
end

return Rpc
