local Utils = require "lib.utils"

---@class EventLoopThread
---@field coroutine thread
---@field event? string
---@field callback? function

local EventLoop = {}

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
    local result = table.pack(coroutine.resume(thread.coroutine, table.unpack(event)))
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
    ---@type EventLoopThread[]
    local nextThreads = {}

    for _, thread in ipairs(Utils.copy(threads)) do
        if thread.event == nil or thread.event == event[1] then
            if runThread(thread, event) then
                table.insert(nextThreads, thread)

                if thread.callback then
                    table.insert(nextThreads, createThread(thread.callback, thread.event))
                end
            end
        else
            table.insert(nextThreads, thread)
        end
    end

    return nextThreads
end

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

    -- os.queueEvent("event-loop:bootstrap")

    threads = runThreads(threads, {})

    while #threads > 0 do
        threads = runThreads(threads, table.pack(os.pullEvent()))
    end
end

---@param event string
---@param ... function
function EventLoop.runUntil(event, ...)
    EventLoop.waitForAny(function()
        EventLoop.pull(event)
    end, EventLoop.run(...))
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

    -- os.queueEvent("event-loop:bootstrap")

    threads = runThreads(threads, {})

    while not anyFinished do
        threads = runThreads(threads, table.pack(os.pullEvent()))
    end
end

return EventLoop
