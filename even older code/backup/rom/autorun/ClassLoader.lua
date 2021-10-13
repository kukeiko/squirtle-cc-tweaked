local files = Disk.getFiles("/rom/entities", true)

for k, v in pairs(files) do
    Scripts.load(v)
end

local files = Disk.getFiles("/rom/libs", true)

for k, v in pairs(files) do
    Scripts.load(v)
end

local files = Disk.getFiles("/rom/services", true)

for k, v in pairs(files) do
    Scripts.load(v)
end

local files = Disk.getFiles("/rom/apps", true)

for k, v in pairs(files) do
    Scripts.load(v)
end

local files = Disk.getFiles("/rom/clients", true)

for k, v in pairs(files) do
    Scripts.load(v)
end