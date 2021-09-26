-- wget https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/installers/storage-sorter.installer.lua install
local baseUrl = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main"
local files = {
    "/apps/storage-sorter.lua",
    "/startup/storage-sorter.autocomplete.lua",
    "/libs/container.lua",
    "/libs/fuel-dictionary.lua",
    "/libs/home.lua",
    "/libs/inventory.lua",
    "/libs/logger.lua",
    "/libs/monitor-modem-proxy.lua",
    "/libs/monitor.lua",
    "/libs/peripheral.lua",
    "/libs/refueler.lua",
    "/libs/sides.lua",
    "/libs/squirtle.lua",
    "/libs/turtle.lua",
    "/libs/utils.lua",
    "/libs/workspace.lua"
}

for i = 1, #files do
    local path = files[i]
    local url = baseUrl .. path
    local cachePreventionHack = string.format("%s?v=%d", url, os.time())
    local response = http.get(cachePreventionHack, nil, true)
    local content = response.readAll()
    response.close()

    local file = fs.open(path, "wb")
    file.write(content)
    file.close()

    print(string.format("Installed %s from %s", path, url))
end
