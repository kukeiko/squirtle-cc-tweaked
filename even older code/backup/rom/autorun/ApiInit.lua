local pattern = "%.lua"
local replaced = { }

for k, v in pairs(_G) do
    local match = k:match(pattern)

    if (match) then
        local friendlyName = k:gsub(pattern, "")
        replaced[friendlyName] = v[friendlyName]
    end
end

for k, v in pairs(replaced) do
    _G[k] = replaced[k]
end