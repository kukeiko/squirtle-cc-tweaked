if package then
    package.path = package.path .. ";/?.lua"
end

local version = require "version"

if not arg then
    return version
end

local function main(args)
    print(string.format("[aqueduct %s] booting...", version()))
    rednet.open("back")
    rednet.broadcast("start", "aqueduct")
end

return main(arg)
