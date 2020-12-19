package.path = package.path .. ";/libs/?.lua"

function main(args)
    if args[2] == "run-on-startup" then
        local file = fs.open("startup/storage-hopper.autorun.lua", "w")
        file.write("shell.run(\"storage-hopper\", \"" .. args[1] .. "\")")
        file.close()
    end

    print("[storage-hopper @ 1.0.0]")

    local argInputSide = args[1]
    local inputSide = "left";
    local outputSide = "right"

    if argInputSide == "from-right" then
        inputSide = "right"
        outputSide = "left"
    end

    local inputChest = peripheral.wrap(inputSide)

    while (true) do
        for i = 1, inputChest.size() do
            inputChest.pushItems(outputSide, i)
        end

        os.sleep(3)
    end
end

main(arg)
