package.path = package.path .. ";/lib/?.lua"

local function main(args)
    print("[aqueduct v1.0.0] booting...")
    rednet.open("back")
    rednet.broadcast("start", "aqueduct")
end

return main(arg)
