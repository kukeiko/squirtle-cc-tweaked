local VStackBranch = { }

--- <summary></summary>
--- <returns type="UI.VStackBranch"></returns>
function VStackBranch.new()
    local instance = UI.Branch.new()
    setmetatable(VStackBranch, { __index = UI.Branch })
    setmetatable(instance, { __index = VStackBranch })

    instance:ctor()

    return instance
end

function VStackBranch:ctor()
    self._buffer = { }
    self._children = { }
end

function VStackBranch:addChild(child)
    VStackBranch.super().addChild(self, child)
    self:updateChildWidth(child)
end

function VStackBranch:updateChildWidth(child)
    local minWidth = child:getMinWidth()
    local width = self:getWidth()
    child = UI.Node.cast(child)

    if (minWidth > width or child:getWidthSizeMode() == UI.Node.SizeMode.Stretch) then
        child:setWidth(width)
    else
        child:setWidth(minWidth)
    end
end

function VStackBranch:setWidth(width)
    VStackBranch.super().setWidth(self, width)

    local children = self:base():getChildren()

    for i = 1, #children do
        self:updateChildWidth(children[i])
    end
end

function VStackBranch:update()
    local child = UI.Node.cast(nil)
    local children = self:getChildren()
    local usedContentHeight = 0
    local stretchedContentHeight = 0
    local stretchedChildren = { }

    -- put stretched children into a table for later processing
    -- update fixed-size children immediately
    for i = 1, #children do
        child = children[i]

        if (child:isVisible()) then
            local childContentHeight = child:getContentHeight()

            if (child:getHeightSizeMode() == UI.Node.SizeMode.Stretch) then
                table.insert(stretchedChildren, { child = child, contentHeight = childContentHeight })
                stretchedContentHeight = stretchedContentHeight + childContentHeight
            else
                child:setHeight(childContentHeight)
                usedContentHeight = usedContentHeight + childContentHeight
                child:update()
            end
        end
    end

    -- spread remaining height across stretched children and update them
    local remainingHeight = self:getHeight() - usedContentHeight
    local totalAllocated = 0

    for i = 1, #stretchedChildren do
        child = stretchedChildren[i].child
        local childContentHeight = stretchedChildren[i].contentHeight

        -- set to default child min height if space available is too small anyway
        if (remainingHeight <= stretchedContentHeight) then
            child:setHeight(childContentHeight)
        else
            local allocated = math.floor((childContentHeight / stretchedContentHeight) * remainingHeight)
            totalAllocated = totalAllocated + allocated

            -- stretch last child to fill up remaining height
            if (i == #stretchedChildren and totalAllocated < remainingHeight) then
                allocated = allocated +(remainingHeight - totalAllocated)
            end

            child:setHeight(allocated)
        end

        child:update()
    end
end

function VStackBranch:getBuffer()
    local buffer = { }
    local child = UI.Node.cast(nil)
    local children = self:getChildren()

    -- concat child buffers vertically
    for i = 1, #children do
        child = children[i]

        if (child:isVisible()) then
            local childBuffer = child:getBuffer()
            for e = 1, #childBuffer do
                table.insert(buffer, childBuffer[e])
            end
        end
    end

    -- pad buffer to fill remaining height
    if (#buffer < self:getHeight()) then
        local diff = self:getHeight() - #buffer

        for i = 1, diff do
            table.insert(buffer, { })
        end
    end

    return buffer
end

function VStackBranch:getContentWidth()
    local child = UI.Node.cast(nil)
    local children = self:getChildren()
    local highestContentWidth = 0

    for i = 1, #children do
        child = children[i]

        if (child:isVisible()) then
            local childContentWidth = child:getContentWidth()

            if (childContentWidth > highestContentWidth) then
                highestContentWidth = childContentWidth
            end
        end
    end

    return highestContentWidth
end

function VStackBranch:getMinWidth()
    local child = UI.Node.cast(nil)
    local children = self:getChildren()
    local highestMinWidth = 0

    for i = 1, #children do
        child = children[i]

        if (child:isVisible()) then
            local childMinWidth = child:getMinWidth()

            if (childMinWidth > highestMinWidth) then
                highestMinWidth = childMinWidth
            end
        end
    end

    return highestMinWidth
end

function VStackBranch:getContentHeight()
    local child = UI.Node.cast(nil)
    local children = self:getChildren()
    local height = 0

    for i = 1, #children do
        child = children[i]

        if (child:isVisible()) then
            height = height + child:getContentHeight()
        end
    end

    return height
end

function VStackBranch:getMinHeight()
    local child = UI.Node.cast(nil)
    local children = self:getChildren()
    local height = 0

    for i = 1, #children do
        child = children[i]

        if (child:isVisible()) then
            height = height + child:getMinHeight()
        end
    end

    return height
end

--- <summary></summary>
--- <returns type="UI.VStackBranch"></returns>
function VStackBranch.cast(VStackBranch)
    return VStackBranch
end

--- <summary></summary>
--- <returns type="UI.Branch"></returns>
function VStackBranch.super()
    return UI.Branch
end

--- <summary></summary>
--- <returns type="UI.Branch"></returns>
function VStackBranch:base()
    return self
end

if (UI == nil) then UI = { } end
UI.VStackBranch = VStackBranch