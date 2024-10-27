local label = os.getComputerLabel()
local programs = {
    ["Database"] = "app/computer/update-host.lua",
    ["Storage"] = "app/computer/io-network.lua",
    ["Home"] = "app/computer/dispenser.lua",
    ["Crafty"] = "app/turtle/io-crafter.lua"
}

if programs[label] then
    shell.run(programs[label])
end
