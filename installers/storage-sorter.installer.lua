local files = {
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/apps/storage-sorter.lua", path = "/apps/storage-sorter.lua"},
    {url = "https://raw.githubusercontent.com/kukeiko/squirtle-cc-tweaked/main/startup/storage-sorter.autocomplete.lua", path = "/startup/item-transfer.autocomplete.lua"}
}

for i = 1, #files do
    local url = files[i].url
    local path = files[i].path
    local response = http.get(url, nil, true)
    local content = response.readAll()
    response.close()

    local file = fs.open(path, "wb")
    file.write(content)
    file.close()
    print(string.format("Installed %s from %s", path, url))
end
