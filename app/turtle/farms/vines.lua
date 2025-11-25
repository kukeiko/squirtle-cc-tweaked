shell.run("refuel", "all")

print("Going up!")

local function foundBlock()
    local success, block = turtle.inspect()

    return success and block.name ~= "minecraft:water"
end

while not foundBlock() do
    os.sleep(1)
    turtle.up()
end

os.sleep(5)
print("Going down!")

while turtle.down() do
end
