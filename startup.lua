local label = os.getComputerLabel()
local programs = {
    ["Database"] = "app/computer/database.lua",
    ["Storage"] = "app/computer/storage.lua bottom",
    ["Home"] = "app/computer/dispenser.lua",
    ["Crafty"] = "app/turtle/io-crafter.lua",
    ["Farmer"] = "app/turtle/farmer.lua",
    ["Lumberjack"] = "app/turtle/lumberjack.lua",
    ["Oak"] = "app/turtle/oak.lua",
    ["Recipes"] = "app/turtle/recipe-reader.lua",
    ["Simon Says: Server"] = "app/computer/simon-says.lua",
    ["Simon Says: Client"] = "app/computer/simon-says.lua client",
    ["Target Practice: Host"] = "app/computer/target-practice client",
    ["Target Practice: Target #1"] = "app/computer/target-practice",
    ["Target Practice: Target #2"] = "app/computer/target-practice",
    ["Target Practice: Target #3"] = "app/computer/target-practice",
    ["Target Practice: Target #4"] = "app/computer/target-practice",
    ["Teleporter"] = "app/computer/teleport nil nil 23",
    ["Xylophone: Server"] = "app/computer/xylophone 2",
    ["Xylophone: Note #1"] = "app/computer/xylophone client 1",
    ["Xylophone: Note #2"] = "app/computer/xylophone client 2",
    ["Test: Resumable Move Back"] = "test/resumable-move-back",
    ["Test: Resumable Move To Point"] = "test/resumable-move-to-point"
}

if programs[label] then
    shell.run(programs[label])
end
