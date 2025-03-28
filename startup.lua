local label = os.getComputerLabel()
local programs = {
    ["Database"] = "app/computer/database.lua",
    ["Storage"] = "app/computer/storage.lua",
    ["Storage Workers"] = "app/computer/storage-workers.lua",
    ["Home"] = "app/computer/dispenser.lua",
    ["Crafty"] = "app/turtle/io-crafter.lua",
    ["Lumberjack"] = "app/turtle/lumberjack/lumberjack.lua",
    ["Recipes"] = "app/turtle/recipe-reader.lua"
}

if programs[label] then
    shell.run(programs[label])
end
