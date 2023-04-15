local EventLoop = require "event-loop"

---@class SearchableList
---@field options SearchableListOption[]
---@field list SearchableListOption[]
---@field searchText string
---@field title? string
---@field index integer
---@field window table
local SearchableList = {}

---@class SearchableListOption
---@field id string
---@field name string

---@param options SearchableListOption[]
---@param title? string
---@return SearchableList
function SearchableList.new(options, title)
    local w, h = term.getSize()

    ---@type SearchableList
    local instance = {
        options = options,
        list = options,
        searchText = "",
        index = 1,
        window = window.create(term.current(), 1, 1, w, h),
        title = title
    }

    setmetatable(instance, {__index = SearchableList})

    return instance
end

---@return SearchableListOption?
function SearchableList:run()
    ---@type SearchableListOption?
    local result = nil

    while (true) do
        self:draw()

        local _, key = EventLoop.pull("key")
        local filterDirty = false

        if (key == keys.f4) then
            break
        elseif (key == keys.enter) then
            if (#self.list > 0) then
                result = self.list[self.index]
                break
            end
        elseif (key == keys.backspace) then
            local len = #self.searchText
            if (len ~= 0) then
                self.searchText = self.searchText:sub(1, len - 1)
                filterDirty = true
            end
        elseif (key == keys.up) then
            self.index = self.index - 1
            if (self.index < 1) then
                if (#self.list == 0) then
                    self.index = 1
                else
                    self.index = #self.list
                end
            end
        elseif (key == keys.down) then
            self.index = self.index + 1
            if (self.index > #self.list) then
                self.index = 1
            end
        elseif (key == keys.space) then
            self.searchText = self.searchText .. " "
            filterDirty = true
        elseif (keys.getName(key):match("^%a$")) then
            self.searchText = self.searchText .. keys.getName(key)
            filterDirty = true
            self.index = 1
        end

        if (filterDirty) then
            self:filter()
        end
    end

    self.window.clear()
    self.window.setCursorPos(1, 1)

    return result
end

function SearchableList:filter()
    ---@type SearchableListOption[]
    local filtered = {}
    local search = self.searchText
    local unfiltered = self.options

    if (#self.searchText == 0) then
        self.list = unfiltered
        return
    end

    for i = 1, #unfiltered do
        local optionName = unfiltered[i].name

        if (optionName:lower():match(search)) then
            table.insert(filtered, unfiltered[i])
        end
    end

    self.list = filtered
end

function SearchableList:draw()
    local win = self.window
    local w, h = win.getSize()

    win.clear()
    win.setCursorPos(1, 1)
    win.clearLine()

    if (#self.searchText > 0) then
        win.write(self.searchText)
    else
        win.write(self.title or "     <type to filter>     ")
    end

    for i = 1, w do
        win.setCursorPos(i, 2)
        win.write("-")
    end

    local listHeight = h - 2
    local list = self.list

    for i = 1, listHeight do
        if (not list[i]) then
            break
        end

        win.setCursorPos(1, i + 2)
        if (self.index == i) then
            win.write("> " .. list[i].name)
        else
            win.write("  " .. list[i].name)
        end
    end
end

return SearchableList
