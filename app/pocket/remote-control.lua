if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

print(string.format("[remote-control %s]", version()))

if turtle then
    rednet.open("right")
else
    rednet.open("back")
end

local turtleId
print(string.rep("-", term.getSize()))
print("[note] make sure you run \"remote\" on the closest turtle that has a wireless modem attached")
print(string.rep("-", term.getSize()))
print("[lookup] trying to find turtle...")

repeat
    turtleId = rednet.lookup("remote-control")
until turtleId

print("[ready] found turtle #" .. turtleId)
print(string.rep("-", term.getSize()))
print("move: W, A, S, D, space, left shift")
print("dig: E, R, F")

while true do
    local _, key = os.pullEvent("key")

    if key == keys.q then
        return
    else
        rednet.send(turtleId, key, "remote-control")
    end
end

