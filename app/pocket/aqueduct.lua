package.path = package.path .. ";/?.lua"

local function main(args)
    print("[aqueduct v1.0.0] booting...")
    rednet.open("back")
    rednet.broadcast("start", "aqueduct")
end

return main(arg)
