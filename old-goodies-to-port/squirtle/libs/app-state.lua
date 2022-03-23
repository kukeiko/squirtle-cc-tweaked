package.path = package.path .. ";/libs/?.lua"

---@class AppState
---@field path string
local AppState = {}

-- local function getDefaultState()
--     return {isOpen = false}
-- end

local function saveState(path, state)
    local file = fs.open("/state/libs/squirtle-buffer.state", "w")
    file.write(textutils.serialize(state))
    file.close()
end

local function loadState(path)
    if not fs.exists("/state/libs/squirtle-buffer.state") then
        return nil
        -- saveState(getDefaultState())
    end

    -- local state = getDefaultState()
    local state = {}
    local file = fs.open("/state/libs/squirtle-buffer.state", "r")
    local savedState = textutils.unserialize(file.readAll())
    file.close()

    for k, v in pairs(savedState) do
        state[k] = v
    end

    return state
end

local function patchState(path, patch)
    local state = loadState(path)

    for k, v in pairs(patch) do
        state[k] = v
    end

    saveState(state)
end

---@return AppState
---@param path string
---@param defaultState? table
function AppState.new(path, defaultState)
    defaultState = defaultState or {}
    local instance = {}
    setmetatable(instance, {__index = AppState})

    return instance
end

function AppState:set(key, value)
    patchState(self.path, {[key] = value})
end

function AppState:get(key)
    return loadState(self.path)[key]
end

-- function AppState.isOpen()
--     return loadState().isOpen
-- end

-- function AppState.open()
--     patchState({isOpen = true})
-- end

-- function AppState.close()
--     patchState({isOpen = false})
-- end

return AppState
