if _ENV["nextId"] then
    return _ENV["nextId"] --[[@as fun() : number]]
end

local id = 0

return function()
    id = id + 1

    return id
end
