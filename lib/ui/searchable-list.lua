local Utils = require "lib.tools.utils"
local EventLoop = require "lib.tools.event-loop"
local nextId = require "lib.tools.next-id"

---@class SearchableList
---@field id integer
---@field options SearchableListOption[]
---@field list SearchableListOption[]
---@field searchText string
---@field title? string
---@field index integer
---@field window table
---@field isRunning boolean
---@field idleTimeout? integer
---@field refreshInterval? integer
---@field refresher? fun() : SearchableListOption[]
local SearchableList = {}

---@class SearchableListOption
---@field id string
---@field name string
---@field suffix? string
---@field data? unknown

---@alias SearchableListAction "select" | "delete"

---@param options SearchableListOption[]
---@param title? string
---@param idleTimeout? integer
---@param refreshInterval? integer
---@param refresher? fun() : SearchableListOption[]
---@param width? integer
---@param height? integer
---@return SearchableList
function SearchableList.new(options, title, idleTimeout, refreshInterval, refresher, width, height)
    local termWidth, termHeight = term.getSize()

    ---@type SearchableList | {}
    local instance = {
        id = nextId(),
        options = options,
        list = options,
        searchText = "",
        index = 1,
        window = window.create(term.current(), 1, 1, width or termWidth, height or termHeight),
        title = title,
        isRunning = false,
        idleTimeout = idleTimeout,
        refreshInterval = refreshInterval,
        refresher = refresher
    }

    setmetatable(instance, {__index = SearchableList})

    return instance
end

---@param options SearchableListOption[]
function SearchableList:setOptions(options)
    self.options = options
    self:filter()

    if self.isRunning then
        self:draw()
    end
end

---@return SearchableListOption?, SearchableListAction?
function SearchableList:run()
    ---@type SearchableListOption?
    local selected = nil
    ---@type SearchableListAction?
    local action = nil
    self.window.setCursorBlink(false)
    self.isRunning = true
    self.searchText = ""
    self:filter()

    local idleTimer, refreshTimer

    if self.refreshInterval and self.refresher then
        refreshTimer = os.startTimer(self.refreshInterval)

        if self.idleTimeout then
            idleTimer = os.startTimer(self.idleTimeout)
        end
    end

    self:draw()

    EventLoop.run(function()
        while true do
            local event, value = EventLoop.pull()

            if event == "searchable-list:selected" and value == self.id then
                break
            elseif event == "timer" and value == idleTimer then
                -- user did not interact for a while => cancel refreshing list options
                refreshTimer = os.cancelTimer(refreshTimer)
            elseif event == "timer" and value == refreshTimer then
                EventLoop.queue("searchable-list:refresh", self.id)
            end
        end
    end, function()
        -- it is possible that user selected something during the refresh call
        while not selected do
            local event, value = EventLoop.pull()

            if event == "searchable-list:selected" and value == self.id then
                break
            elseif event == "searchable-list:refresh" and value == self.id then
                EventLoop.waitForAny(function()
                    -- need to check for idleTimer as refresher() could take a while, potentially causing us to skip pulling it normally
                    while true do
                        local event, value = EventLoop.pull()

                        if event == "timer" and value == idleTimer then
                            break
                        end
                    end
                end, function()
                    local options = self.refresher()
                    self:setOptions(options)

                    if refreshTimer then
                        refreshTimer = os.startTimer(self.refreshInterval)
                    end
                end)
            end
        end
    end, function()
        while true do
            local event, value = EventLoop.pull()
            local filterDirty = false
            local userInteracted = false

            if event == "key" then
                if (value == keys.f4) then
                    EventLoop.queue("searchable-list:selected", self.id)
                    break
                elseif value == keys.enter or value == keys.numPadEnter or value == keys.delete then
                    if (#self.list > 0) then
                        selected = self.list[self.index]
                        action = value == keys.enter and "select" or "delete"
                        EventLoop.queue("searchable-list:selected", self.id)
                        break
                    end
                elseif value == keys.backspace then
                    local len = #self.searchText
                    if (len ~= 0) then
                        self.searchText = self.searchText:sub(1, len - 1)
                        filterDirty = true
                    end
                elseif value == keys.up then
                    self.index = self.index - 1
                    if (self.index < 1) then
                        if (#self.list == 0) then
                            self.index = 1
                        else
                            self.index = #self.list
                        end
                    end
                elseif value == keys.down then
                    self.index = self.index + 1
                    if (self.index > #self.list) then
                        self.index = 1
                    end
                elseif value == keys.pageUp then
                    self.index = math.max(1, self.index - 10)
                elseif value == keys.pageDown then
                    self.index = math.min(#self.list, self.index + 10)
                elseif value == keys.home then
                    self.index = 1
                elseif value == keys["end"] then
                    self.index = #self.list
                end

                userInteracted = true
            elseif event == "char" then
                self.searchText = self.searchText .. value
                filterDirty = true
                userInteracted = true
            elseif event == "shell-window:visible" then
                userInteracted = true
            end

            if userInteracted and self.idleTimeout and self.refreshInterval and self.refresher then
                idleTimer = Utils.restartTimer(idleTimer, self.idleTimeout)

                if not refreshTimer then
                    refreshTimer = os.startTimer(self.refreshInterval)
                end
            end

            if filterDirty then
                self:filter()
            end

            if userInteracted then
                self:draw()
            end
        end
    end)

    if refreshTimer then
        os.cancelTimer(refreshTimer)
    end

    if idleTimer then
        os.cancelTimer(idleTimer)
    end

    self.window.clear()
    self.isRunning = false

    return selected, action
end

function SearchableList:filter()
    ---@type SearchableListOption[]
    local filtered = {}
    local search = Utils.escapePpattern(self.searchText)
    local unfiltered = self.options
    local selectedId = (self.list[self.index] or {}).id

    if (#self.searchText == 0) then
        self.list = unfiltered
    else
        for i = 1, #unfiltered do
            local optionName = unfiltered[i].name

            if (optionName:lower():match(search)) then
                table.insert(filtered, unfiltered[i])
            end
        end

        self.list = filtered
    end

    local newIndex = Utils.findIndex(self.list, function(item)
        return item.id == selectedId
    end)

    self.index = newIndex or 1
end

function SearchableList:draw()
    local win = self.window
    local w, h = win.getSize()

    win.setCursorPos(1, 1)

    if #self.searchText > 0 then
        if #self.searchText > w then
            win.write(Utils.ellipsisLeft(self.searchText, w))
        else
            win.write(Utils.padRight(self.searchText, w))
        end
    else
        if self.title and #self.title > w then
            win.write(Utils.ellipsisLeft(self.title, w))
        else
            win.write(Utils.pad(self.title or "<type to filter>", w))
        end
    end

    win.setCursorPos(1, 2)
    win.write(string.rep("-", w))

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
        win.setCursorPos(1, i + headerHeight)

        if (not option) then
            win.clearLine()
        else
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
                win.setCursorPos(w - 2, i + headerHeight)

                if i == scrollerIndex then
                    win.write(" \140 ")
                else
                    win.blit(" ", colors.toBlit(colors.black), colors.toBlit(colors.black))
                    win.blit(" ", colors.toBlit(colors.black), colors.toBlit(colors.gray))
                    win.blit(" ", colors.toBlit(colors.black), colors.toBlit(colors.black))
                end
            end

            win.setTextColor(colors.white)
        end
    end

    win.setCursorPos(1, 1)
end

return SearchableList
