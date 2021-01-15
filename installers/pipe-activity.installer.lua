-- wget https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/installers/pipe-activity.installer.lua install
local baseUrl = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main"
local files = {
    "/apps/pipe-activity.lua",
    "/startup/pipe-activity.autocomplete.lua",
    "/libs/utils.lua"
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
