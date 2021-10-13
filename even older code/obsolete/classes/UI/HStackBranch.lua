local HStackBranch = { }

--- <summary></summary>
--- <returns type="UI.HStackBranch"></returns>
function HStackBranch.new()
    local instance = UI.Branch.new()
    setmetatable(HStackBranch, { __index = UI.Branch })
    setmetatable(instance, { __index = HStackBranch })

    instance:ctor()

    return instance
end

function HStackBranch:ctor()
    self._buffer = { }
    self._children = { }
end

function HStackBranch:addChild(child)
    HStackBranch.super().addChild(self, child)
    --    self:updateChildrenSize()
end

function HStackBranch:setWidth(width)
    Log.debug("Setting width to", width)
    HStackBranch.super().setWidth(self, width)
    self:updateChildrenSize()
end

function HStackBranch:updateChildrenSize()
    Log.debug("-----------------------")
    -- todo: i made contentWidth ignore the currently set width (was necessary) - what about contentheight?

    local children = self:base():getChildren()
    local child = UI.Node.cast(nil)
    local availableWidth = self:getWidth()
    local totalContentWidth = self:getContentWidth()
    local totalMinWidth = self:getMinWidth()

    if (availableWidth >= totalContentWidth and availableWidth >= totalMinWidth) then
        Log.debug("Available width is more than total content width / total min width")
        local stretchedChildren = { }
        local stretchedContentWidth = 0
        local usedContentWidth = 0

        for i = 1, #children do
            child = children[i]

            if (child:isVisible()) then
                local childContentWidth = child:getContentWidth()

                if (child:getWidthSizeMode() == UI.Node.SizeMode.Stretch) then
                    table.insert(stretchedChildren, { child = child, contentWidth = childContentWidth })
                    stretchedContentWidth = stretchedContentWidth + childContentWidth
                else
                    child:setWidth(childContentWidth)
                    child:setHeight(child:getContentHeight())
                    usedContentWidth = usedContentWidth + childContentWidth
                    child:update()
                end
            end
        end

        local remainingWidth = availableWidth - usedContentWidth
        local totalAllocated = 0

        for i = 1, #stretchedChildren do
            child = stretchedChildren[i].child

            local childContentWidth = stretchedChildren[i].contentWidth
            local allocated = math.floor((childContentWidth / stretchedContentWidth) * remainingWidth)

            totalAllocated = totalAllocated + allocated

            -- stretch last child to fill up remaining width (may exist due to flooring)
            if (i == #stretchedChildren and totalAllocated < remainingWidth) then
                allocated = allocated +(remainingWidth - totalAllocated)
            end

            child:setWidth(allocated)
            child:setHeight(child:getContentHeight())
            child:update()
        end
    else
        for i = 1, #children do
            child = children[i]
            child:setWidth(child:getMinWidth())
            child:setHeight(child:getContentHeight())
            child:update()
        end

        if (availableWidth >= totalMinWidth) then
            -- now some children are needlessly small. find those with more content than min width
            -- and allocate width by weight.
            local resizableChildren = { }
            local remainingWidth = availableWidth
            local resizableWidth = 0

            for i = 1, #children do
                child = children[i]

                remainingWidth = remainingWidth - child:getMinWidth()

                if (child:getContentWidth() > child:getMinWidth()) then
                    resizableWidth = resizableWidth + child:getContentWidth()
                    resizableChildren[#resizableChildren + 1] = child
                end
            end

            local totalAllocated = 0

            for i = 1, #resizableChildren do
                child = resizableChildren[i]

                local allocated = math.floor((child:getContentWidth() / resizableWidth) * remainingWidth)

                totalAllocated = totalAllocated + allocated

                if (i == #resizableChildren and totalAllocated < remainingWidth) then
                    allocated = allocated +(remainingWidth - totalAllocated)
                end

                child:setWidth(allocated)
                child:setHeight(child:getContentHeight())
                child:update()
            end
        end
    end
end

function HStackBranch:getBuffer()
    local buffer = { }
    local children = self:base():getChildren()
    local child = UI.Node.cast(nil)
    local totalHeight = self:getContentHeight()
    local childWidth = 0

    Log.debug("buffer!")

    for i = 1, #children do
        child = children[i]
        local childHeight = child:getHeight()
        local childBuffer = child:getBuffer()

        for e = 1, childHeight do
            if (buffer[e] == nil) then
                buffer[e] = { }
            end

            buffer[e] = table.concatTable(buffer[e], childBuffer[e])
            childWidth = #childBuffer[e]
        end

        if (childHeight < totalHeight) then
            local offset = #buffer[childHeight + 1] + 1

            for y = childHeight + 1, totalHeight do
                for x = offset, offset + childWidth - 1 do
                    buffer[y][x] = " "
                end
            end
        end
    end

    return buffer
end

function HStackBranch:getContentWidth()
    local children = self:base():getChildren()
    local child = UI.Node.cast(nil)
    local totalContentWidth = 0;

    for i = 1, #children do
        child = children[i]
        totalContentWidth = totalContentWidth + child:getContentWidth()
    end

    return totalContentWidth
end

function HStackBranch:getMinWidth()
    local children = self:base():getChildren()
    local child = UI.Node.cast(nil)
    local totalMinWidth = 0;

    for i = 1, #children do
        child = children[i]
        totalMinWidth = totalMinWidth + child:getMinWidth()
    end

    return totalMinWidth
end

function HStackBranch:getContentHeight()
    local children = self:base():getChildren()
    local child = UI.Node.cast(nil)
    local highestContentHeight = 0;

    for i = 1, #children do
        child = children[i]
        local childContentHeight = child:getContentHeight()

        if (childContentHeight > highestContentHeight) then
            highestContentHeight = childContentHeight
        end
    end

    return highestContentHeight
end

function HStackBranch:getMinHeight()
    local children = self:base():getChildren()
    local child = UI.Node.cast(nil)
    local highestMinHeight = 0;

    for i = 1, #children do
        child = children[i]
        local childMinHeight = child:getMinHeight()

        if (childMinHeight > highestMinHeight) then
            highestMinHeight = childMinHeight
        end
    end

    return highestMinHeight
end

--- <summary></summary>
--- <returns type="UI.HStackBranch"></returns>
function HStackBranch.cast(HStackBranch)
    return HStackBranch
end

--- <summary></summary>
--- <returns type="UI.Branch"></returns>
function HStackBranch.super()
    return UI.Branch
end

--- <summary></summary>
--- <returns type="UI.Branch"></returns>
function HStackBranch:base()
    return self
end

if (UI == nil) then UI = { } end
UI.HStackBranch = HStackBranch