package.path = package.path .. ";/lib/?.lua"

local function main(args)
    print("[remote-control v 1.0.0] booting...")
    if turtle then
        rednet.open("right")
    else
        rednet.open("back")
    end

    local turtleId

    print("trying to find turtle...")

    repeat
        turtleId = rednet.lookup("remote-control")
    until turtleId

    print("found", turtleId)

    while true do
        local _, key = os.pullEvent("key")

        if key == keys.q then
            return
        else
            rednet.send(turtleId, key, "remote-control")
        end
    end
end

return main(arg)
