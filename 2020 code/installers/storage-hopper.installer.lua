-- wget https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/installers/storage-hopper.installer.lua install
local files = {
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/apps/storage-hopper.lua", path = "/apps/storage-hopper.lua"},
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/startup/storage-hopper.autocomplete.lua", path = "/startup/storage-hopper.autocomplete.lua"}
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
