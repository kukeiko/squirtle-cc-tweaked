local EventLoop = require "event-loop"
local Utils = require "utils"

---@class SearchableList
---@field options SearchableListOption[]
---@field list SearchableListOption[]
---@field searchText string
---@field title? string
---@field index integer
---@field window table
---@field isRunning boolean
local SearchableList = {}

---@class SearchableListOption
---@field id string
---@field name string
---@field suffix? string

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
        title = title,
        isRunning = false
    }

    setmetatable(instance, {__index = SearchableList})

    return instance
end

---@param options SearchableListOption[]
function SearchableList:setOptions(options)
    local selectedId = (self.options[self.index] or {}).id
    self.options = options
    local newIndex = Utils.findIndex(options, function(item, index)
        return item.id == selectedId
    end)

    self:filter()

    if newIndex then
        self.index = newIndex

        if self.index > #self.list then
            self.index = 1
        end
    end

    if self.isRunning then
        self:draw()
    end
end

---@return SearchableListOption?
function SearchableList:run()
    ---@type SearchableListOption?
    local result = nil
    self.window.setCursorBlink(false)
    self.isRunning = true

    while (true) do
        self:draw()

        local event, value = EventLoop.pull()
        local filterDirty = false

        if event == "key" then
            if (value == keys.f4) then
                break
            elseif (value == keys.enter) then
                if (#self.list > 0) then
                    result = self.list[self.index]
                    break
                end
            elseif (value == keys.backspace) then
                local len = #self.searchText
                if (len ~= 0) then
                    self.searchText = self.searchText:sub(1, len - 1)
                    filterDirty = true
                end
            elseif (value == keys.up) then
                self.index = self.index - 1
                if (self.index < 1) then
                    if (#self.list == 0) then
                        self.index = 1
                    else
                        self.index = #self.list
                    end
                end
            elseif (value == keys.down) then
                self.index = self.index + 1
                if (self.index > #self.list) then
                    self.index = 1
                end
            end
        elseif event == "char" then
            self.searchText = self.searchText .. value
            filterDirty = true
            self.index = 1
        end

        if (filterDirty) then
            self:filter()
        end
    end

    self.window.clear()
    self.window.setCursorPos(1, 1)
    self.isRunning = false

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
    local listOffset = 0
    local listOffsetMax = #list - listHeight
    local drawScroller = #list > listHeight
    local scrollerWidth = 0
    local headerHeight = 2

    if drawScroller then
        scrollerWidth = 3
    end

    if #list > listHeight then
        local half = math.floor(listHeight / 2)

        if self.index > half then
            listOffset = math.min(self.index - half, listOffsetMax)
        end
    end

    local scrollerIndex = math.max(1, math.floor(listHeight * (listOffset / listOffsetMax)))

    for i = 1, listHeight do
        local option = list[i + listOffset]

        if (not option) then
            break
        end

        win.setCursorPos(1, i + headerHeight)

        if (self.index - listOffset == i) then
            win.setTextColor(colors.white)
        else
            win.setTextColor(colors.lightGray)
        end

        local suffix = option.suffix or ""
        local labelMaxLength = w - (#suffix + 1) - scrollerWidth
        local label = Utils.padRight(Utils.ellipsis(option.name, labelMaxLength), labelMaxLength) .. " " .. suffix
        win.write(label)

        if drawScroller then
            win.setCursorPos(w - 1, i + headerHeight)

            if i == scrollerIndex then
                win.write("\140")
            else
                win.blit(" ", colors.toBlit(colors.black), colors.toBlit(colors.gray))
            end
        end

        win.setTextColor(colors.white)
    end
end

return SearchableList
