local printProgress = require "io-network.print-progress"

---@param timeout integer
---@return "timeout" | "key"
return function(timeout)
    local steps = 10
    local x, y = printProgress(0, steps)

    local first = parallel.waitForAny(function()
        local timeoutTick = timeout / steps

        for i = 1, steps do
            os.sleep(timeoutTick)
            printProgress(i, steps, x, y)
        end
    end, function()
        os.pullEvent("key")
        printProgress(steps, steps, x, y)
    end)

    if first == 1 then
        return "timeout"
    else
        return "key"
    end
end
