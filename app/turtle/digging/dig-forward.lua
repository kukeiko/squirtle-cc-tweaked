---@param args table
local function main(args)
    print("[dig-forward v1.0.0] booting...")
    local length = tonumber(args[1]) or 7

    for _ = 1, length do
        if turtle.getFuelLevel() == 0 then
            print("[help] out of fuel, exiting")
        end

        while not turtle.forward() do
            turtle.dig()
        end

        turtle.digUp()
        turtle.digDown()
    end
end

return main(arg)
