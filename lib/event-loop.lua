local Utils = require "utils"

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
    local result = table.pack(coroutine.resume(thread.coroutine, table.unpack(event)))

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

---@param event string
---@param callback? function
function EventLoop.pull(event, callback)
    return coroutine.yield(event, callback)
end

---@param ... function
function EventLoop.run(...)
    local threads = Utils.map({...}, function(fn)
        return createThread(fn)
    end)

    os.queueEvent("event-loop:bootstrap")

    while #threads > 0 do
        threads = runThreads(threads, table.pack(os.pullEvent()))
    end
end

return EventLoop
