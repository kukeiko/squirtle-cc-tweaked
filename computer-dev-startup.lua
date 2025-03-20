-- this file needs to be manually copied to folder of computer 21
local label = os.getComputerLabel()

if label == nil then
    return nil
end

if string.find(label, "switch") then
    shell.run("subway-switch")
elseif string.find(label, "hub") then
    shell.run("subway-hub right")
end

local programs = {["Dispenser"] = "dispenser"}

if programs[label] then
    shell.run(programs[label])
end
