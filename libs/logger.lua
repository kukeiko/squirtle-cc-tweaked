package.path = package.path .. ";/libs/?.lua"

local Logger = {}

function Logger.log(msg)
    print(Logger.formattedLocalTime() .. " " .. msg)
end

function Logger.debug(msg)
    print(Logger.formattedLocalTime() .. " " .. msg)
end

function Logger.warn(msg)
    print(Logger.formattedLocalTime() .. " ! " .. msg)
end

function Logger.error(msg)
    print(Logger.formattedLocalTime() .. " E " .. msg)
end

function Logger.formattedLocalTime()
    local osTime = os.time("local")
    local hours = math.floor(osTime)
    local minutes = math.floor((osTime % 1) * 60)

    if minutes < 10 then
        minutes = "0" .. minutes
    end

    return "[" .. hours .. ":" .. minutes .. "]"
end

return Logger
