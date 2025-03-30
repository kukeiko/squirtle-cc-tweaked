local label = os.getComputerLabel()
local programs = {
    ["Database"] = "app/computer/database.lua",
    ["Storage"] = "app/computer/storage.lua",
    ["Storage Workers"] = "app/computer/storage-workers.lua",
    ["Home"] = "app/computer/dispenser.lua",
    ["Crafty"] = "app/turtle/io-crafter.lua",
    ["Lumberjack"] = "app/turtle/lumberjack/lumberjack.lua",
    ["Recipes"] = "app/turtle/recipe-reader.lua",
    ["Simon Says: Server"] = "app/computer/simon-says.lua 2",
    ["Simon Says: Client"] = "app/computer/simon-says.lua client",
    ["Target Practice: Host"] = "app/computer/target-practice client",
    ["Target Practice: Target #1"] = "app/computer/target-practice",
    ["Target Practice: Target #2"] = "app/computer/target-practice",
    ["Target Practice: Target #3"] = "app/computer/target-practice",
    ["Target Practice: Target #4"] = "app/computer/target-practice"
}

if programs[label] then
    shell.run(programs[label])
end
