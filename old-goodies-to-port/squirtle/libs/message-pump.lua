local function copyTable(self)
    local copy = {}

    for k, v in pairs(self) do
        copy[k] = v
    end

    return copy
end

---@class MessagePump
---@field eventListeners boolean[]
---@field coroutines thread[]
---@field coroutineFilters string[]
---@field nextCoroutineId integer
---@field numCoroutines integer
---@field eliminate thread[]
---@field isRunning boolean
---@field doQuit boolean
local MessagePump = {}

---@return MessagePump
function MessagePump.new()
    ---@type MessagePump
    local instance = {
        eventListeners = {},
        coroutines = {},
        coroutineFilters = {},
        nextCoroutineId = 1,
        numCoroutines = 0,
        eliminate = {},
        isRunning = false,
        doQuit = false
    }

    setmetatable(instance, {__index = MessagePump})

    return instance
end

--- Adds a coroutine to the MessagePump.
--- @param event string event name the coroutine initially waits for (nil for any)
--- @param coro thread coroutine
--- @param name? string (optional) name of the coroutine
function MessagePump:add(event, coro, name)
    local id = string.format("%s:%d", (name or "thread"), self.nextCoroutineId)

    self.coroutines[id] = coro
    self.coroutineFilters[id] = event
    self.nextCoroutineId = self.nextCoroutineId + 1
    self.numCoroutines = self.numCoroutines + 1

    return id
end

--- Wraps a handler in a coroutine and adds it to the MessagePump.
--- @param event string event name the coroutine initially waits for (nil for any)
--- @param handler function the handler to wrap into a coroutine
--- @param name? string (optional) name of the coroutine
function MessagePump:create(event, handler, name)
    return self:add(event, coroutine.create(handler), name)
end

--- Creates an event handler.
--- Executes the handler as a separate coroutine each time the event occurs.</br>
--- Any handler added this way will remain indefinitely until MessagePump:off() is used to remove it.
---@param event string event name to listen to
---@param handler function handler to execute
---@param name? string (optional) name of the coroutine
function MessagePump:on(event, handler, name)
    local couroutineId

    local helper = function(...)
        local args = {...}
        table.remove(args, 1)

        while self.eventListeners[couroutineId] do
            local coro = coroutine.create(handler)
            local success, param = coroutine.resume(coro, table.unpack(args))

            if not success then
                print("[msg-pump] thread died: " .. param)
                -- Log.error("[msg-pump] a coroutine died: " .. param)
            end

            if coroutine.status(coro) == "suspended" then
                self:add(param, coro)
            end

            args = {coroutine.yield(event)}
            table.remove(args, 1)
        end
    end

    couroutineId = self:create(event, helper, name)
    self.eventListeners[couroutineId] = true

    return couroutineId
end

--- Removes an event handler.
--- @param couroutineId string the id to the event handler (returned by MessagePump:on())
function MessagePump:off(couroutineId)
    if (self.eventListeners[couroutineId]) then
        self.eventListeners[couroutineId] = nil
        self.eliminate[couroutineId] = self.coroutines[couroutineId]
    end
end

--- Stops execution of the MessagePump:run() routine.
--- Coroutines listening to the current event pulled that have not yet been invoked are still executed.
function MessagePump:quit()
    self.doQuit = true
end

--- Removes all coroutines from the pool.
function MessagePump:reset()
    self.nextCoroutineId = 1
    self.coroutines = {}
    self.numCoroutines = 0
    self.coroutineFilters = {}
    self.eventListeners = {}
    self.eliminate = {}
    self.isRunning = false
    self.doQuit = false
end

function MessagePump:remove(coroId)
    return self:removeCoroutine(coroId)
end

function MessagePump:removeCoroutine(coroId)
    self.coroutines[coroId] = nil
    self.coroutineFilters[coroId] = nil
    self.numCoroutines = self.numCoroutines - 1
end

--- Pull the next event that matches the given name.
--- Almost alias of os.pullEvent(eventName): does not return the event name
--- @param event string event to pull
--- @return ... parameters of the pulled event
function MessagePump.pull(event)
    local args = {os.pullEvent(event)}
    table.remove(args, 1)

    return table.unpack(args)
end

--- Pull the next event that matches the given names.
function MessagePump.pullMany(...)
    local requested = {...}
    local eventNames = {}

    for i = 1, #requested do
        eventNames[requested[i]] = true
    end

    while (true) do
        local args = {os.pullEvent()}

        if (eventNames[args[1]] ~= nil) then
            return table.unpack(args)
        end
    end
end

function MessagePump.queue(...)
    os.queueEvent(...)
end

function MessagePump:run(...)
    local funcs = {...}

    for i = 1, #funcs do
        if (type(funcs[i]) == "function") then
            local name = nil
            if (type(funcs[i + 1]) == "string") then
                name = funcs[i + 1]
            end
            self:create(nil, funcs[i], name)
        end
    end

    -- bootstraps given coroutines
    os.queueEvent("squirtle:message_pump_bootstrap")

    if (self.isRunning) then
        return true
    end
    self.isRunning = true

    while (self.numCoroutines > 0 and not self.doQuit) do
        -- make a copy of current coroutines since original may change during coroutine execution
        local coroutines = copyTable(self.coroutines)
        self.eliminate = {}
        local eventData = {os.pullEventRaw()}
        local eventName = eventData[1]

        --        Log.debug("------------------------------------------------")
        --        Log.debug("[msg-pump] pulled " .. string.gsub(textutils.serialize(eventData), "[\n ]", ""))
        for coroId, coro in pairs(coroutines) do
            local filter = self.coroutineFilters[coroId]

            if (filter == nil or eventName == filter) then
                local debugmsg = "[msg-pump] "
                if (filter == nil) then
                    debugmsg = debugmsg .. "[nil] => " .. coroId .. " "
                else
                    debugmsg = debugmsg .. "[" .. filter .. "] => " .. coroId .. " "
                end

                local success, param = coroutine.resume(coro, table.unpack(eventData))
                local status = coroutine.status(coro)

                if (not success) then
                    print("[msg-pump] a thread died: " .. param)
                    -- Log.error("[msg-pump] a coroutine died: " .. param)
                    self:reset()
                    error(param, 0)
                end

                if (status == "dead") then
                    self.eliminate[coroId] = coro
                    debugmsg = debugmsg .. "ended"
                else
                    self.coroutineFilters[coroId] = param
                    if (param == nil) then
                        debugmsg = debugmsg .. "=> [nil]"
                    else
                        debugmsg = debugmsg .. "=> [" .. param .. "]"
                    end
                end

                print(debugmsg)
                -- Log.debug(debugmsg)
            end
        end

        for coroId, coro in pairs(self.eliminate) do
            self:removeCoroutine(coroId)
        end

        if (eventName == "terminate") then
            print("[msg-pump] terminated")
            break
        end
    end

    self:reset()
end

return MessagePump
