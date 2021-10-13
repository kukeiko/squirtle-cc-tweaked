local Test = { }

--- <summary>
--- </summary>
--- <returns type="Test"></returns>
function Test.new(window)
    local instance = System.App.new(window)
    setmetatable(Test, { __index = System.App })
    setmetatable(instance, { __index = Test })
    instance:ctor()

    return instance
end

function Test:ctor()
    local win = self:base():getWindow()

    local hs = UI.HStackBranch.new()
    local vs = UI.VStackBranch.new()

    local text_A = UI.Label.new("This is a text with some words.")
    local text_B = UI.Label.new("Foobar!")
    local text_C = UI.Label.new("I am a paragraph dumdideldei.")

--    text_A:setMinWidth(text_A:getContentWidth())
    text_B:setMinWidth(text_B:getContentWidth())
--    text_C:setMinWidth(text_C:getContentWidth())

    hs:addChild(text_A)
    hs:addChild(text_B)
    hs:addChild(text_C)

    hs:setHeightSizeMode(UI.Node.SizeMode.Stretch)

    vs:addChild(hs)
    vs:addChild(hs)

    

    win:setContent(vs)
end

function Test:run()
    Log.close()
end

--- <summary></summary>
--- <returns type="Apps.Test"></returns>
function Test.cast(instance)
    return instance
end

--- <summary></summary>
--- <returns type="System.App"></returns>
function Test.super()
    return UI.Node
end

--- <summary></summary>
--- <returns type="System.App"></returns>
function Test:base()
    return self
end

if (Apps == nil) then Apps = { } end
Apps.Test = Test