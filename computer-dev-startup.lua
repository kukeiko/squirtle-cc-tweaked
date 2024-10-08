local label = os.getComputerLabel()

if label ~= nil then
    if string.find(label, "switch") then
        shell.run("subway-switch")
    elseif string.find(label, "hub") then
        shell.run("subway-hub right")
    end
end