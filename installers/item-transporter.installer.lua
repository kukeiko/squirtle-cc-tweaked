-- wget https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/installers/item-transporter.installer.lua install
local files = {
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/apps/item-transporter.lua", path = "/apps/item-transporter.lua"},
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/startup/item-transporter.autocomplete.lua", path = "/startup/item-transporter.autocomplete.lua"},
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/libs/monitor-modem-proxy.lua", path = "/libs/monitor-modem-proxy.lua"},
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/libs/monitor.lua", path = "/libs/monitor.lua"},
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/libs/squirtle.lua", path = "/libs/squirtle.lua"}
}

for i = 1, #files do
    local url = files[i].url
    local path = files[i].path
    local cachePreventionHack = string.format("%s?v=%d", url, os.time())
    local response = http.get(cachePreventionHack, nil, true)
    local content = response.readAll()
    response.close()

    local file = fs.open(path, "wb")
    file.write(content)
    file.close()

    print(string.format("Installed %s from %s", path, url))
end
