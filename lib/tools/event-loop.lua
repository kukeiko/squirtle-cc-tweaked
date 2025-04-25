local Utils = require "lib.tools.utils"

---@class EventLoopThread
---@field coroutine thread
---@field event? string
---@field accept? fun(event: string) : boolean
---@field callback? function
---@field window? table

local EventLoop = {}

---@type EventLoopThread?
local currentThread

---@type table<string, integer>
local pulledEventStats = {}

---@return table<string, integer>
function EventLoop.getPulledEventStats()
    return pulledEventStats
end

---@param fn function
---@param event? string
---@return EventLoopThread
local function createThread(fn, event)
    ---@type EventLoopThread
    local thread = {coroutine = coroutine.create(fn), event = event}

    return thread
end

---@param thread EventLoopThread
---@param event table
local function runThread(thread, event)
    local start = os.epoch("utc")
    currentThread = thread
    local original

    if thread.window then
        original = term.redirect(thread.window)
    end

    local result = table.pack(coroutine.resume(thread.coroutine, table.unpack(event)))

    if original then
        term.redirect(original)
    end

    currentThread = nil
    local duration = os.epoch("utc") - start

    if duration >= 250 then
        print(string.format("[event-loop] thread took %dms", duration))
    end

    if not result[1] then
        error(result[2])
    end

    if coroutine.status(thread.coroutine) == "dead" then
        return false
    end

    thread.event = result[2]

    if type(result[3]) == "function" then
        thread.callback = result[3]
    else
        thread.callback = nil
    end

    return true
end

---@param threads EventLoopThread[]
---@param event table
---@return EventLoopThread[]
local function runThreads(threads, event)
    if event[1] == "terminate" then
        return {}
    end

    if currentThread == nil then
        -- only record events pulled from root
        pulledEventStats[event[1] or "nil"] = (pulledEventStats[event[1] or "nil"] or 0) + 1
    end

    ---@type EventLoopThread[]
    local nextThreads = {}

    for _, thread in ipairs(Utils.copy(threads)) do
        if (thread.event == nil or thread.event == event[1]) and (thread.accept == nil or thread.accept(event[1])) then
            if runThread(thread, event) then
                table.insert(nextThreads, thread)

                if thread.callback then
                    -- [todo] copy over configurable options like "window"
                    table.insert(nextThreads, createThread(thread.callback, thread.event))
                end
            end
        else
            table.insert(nextThreads, thread)
        end
    end

    return nextThreads
end

-- [todo] throw error if not called within a coroutine run by EventLoop, as we otherwise can't properly deal with the "terminate" event (i think)
---@param event? string
---@param callback? function
function EventLoop.pull(event, callback)
    return coroutine.yield(event, callback)
end

---@param event string
---@param ... unknown
function EventLoop.queue(event, ...)
    os.queueEvent(event, ...)
end

---@param event string
---@param time number
function EventLoop.debounce(event, time)
    local result = table.pack(EventLoop.pull(event))
    local debounce = os.startTimer(time)

    parallel.waitForAny(function()
        repeat
            local _, timerId = EventLoop.pull("timer")
        until timerId == debounce
    end, function()
        while true do
            result = table.pack(EventLoop.pull(event))
            debounce = os.startTimer(3)
        end
    end)

    return table.unpack(result)
end

---@param ... function
function EventLoop.run(...)
    local threads = Utils.map({...}, function(fn)
        return createThread(fn)
    end)

    threads = runThreads(threads, {})

    while #threads > 0 do
        threads = runThreads(threads, table.pack(EventLoop.pull()))
    end
end

---@param ... function
function EventLoop.createRun(...)
    local threads = Utils.map({...}, function(fn)
        return createThread(fn)
    end)

    ---@type EventLoopThread[]
    local addedThreads = {}

    ---@param ... function
    local function add(...)
        for _, fn in pairs({...}) do
            table.insert(addedThreads, createThread(fn))
        end
    end

    local function run()
        -- [todo] should also already run the addedThreads
        threads = runThreads(threads, {})

        while #threads > 0 do
            threads = runThreads(threads, table.pack(EventLoop.pull()))

            if #addedThreads > 0 then
                for _, thread in pairs(runThreads(addedThreads, {})) do
                    table.insert(threads, thread)
                end

                addedThreads = {}
            end
        end
    end

    return add, run
end

---@param options { accept?: fun(event: string) : boolean; window?: table }
function EventLoop.configure(options)
    if currentThread == nil then
        error("no active thread")
    end

    currentThread.accept = options.accept or currentThread.accept
    currentThread.window = options.window or currentThread.window
end

---@param ... function
function EventLoop.waitForAny(...)
    local anyFinished = false
    local threads = Utils.map({...}, function(fn)
        return createThread(function()
            fn()
            anyFinished = true
        end)
    end)

    threads = runThreads(threads, {})

    while not anyFinished and #threads > 0 do
        threads = runThreads(threads, table.pack(EventLoop.pull()))
    end
end

---Run functions until a specific event is pulled.
---@param event string
---@param ... function
---@return boolean
function EventLoop.runUntil(event, ...)
    local fns = {...}
    local hitEvent = false

    EventLoop.waitForAny(function()
        EventLoop.pull(event)
        hitEvent = true
    end, function()
        EventLoop.run(table.unpack(fns))
    end)

    return hitEvent
end

---@param timeout? number
---@param ... function
---@return boolean true if timeout was not hit
function EventLoop.runTimed(timeout, ...)
    local fns = {...}
    local timeoutHit = false

    if timeout == nil then
        EventLoop.run(table.unpack(fns))
    else
        EventLoop.waitForAny(function()
            os.sleep(timeout)
            timeoutHit = true
        end, function()
            EventLoop.run(table.unpack(fns))
        end)
    end

    return not timeoutHit
end

---@param timerId integer
function EventLoop.pullTimer(timerId)
    while true do
        local _, candidate = EventLoop.pull("timer")

        if candidate == timerId then
            return
        end
    end
end

---@param key number
function EventLoop.pullKey(key)
    while true do
        local _, pulledKey = EventLoop.pull("key")

        if pulledKey == key then
            return
        end
    end
end

---@param keys number[]
---@return number
function EventLoop.pullKeys(keys)
    while true do
        local _, pulledKey = EventLoop.pull("key")

        if Utils.indexOf(keys, pulledKey) then
            return pulledKey
        end
    end
end

---@param min integer
---@param max integer
---@return integer
function EventLoop.pullInteger(min, max)
    if min < 0 or min > 9 then
        error(string.format("min must be in range [0, 9] (got %d)", min))
    end

    if max < 0 or max > 9 then
        error(string.format("max must be in range [0, 9] (got %d)", max))
    end

    if min > max then
        error(string.format("max must be greater than min (got %d, %d)", min, max))
    end

    while true do
        local _, key = EventLoop.pull("char")
        local int = tonumber(key)

        if int ~= nil and int >= min and int <= max then
            return int
        end
    end
end

return EventLoop
