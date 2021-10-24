local dig = require "kiwi.turtle.dig"
local face = require "kiwi.turtle.face"
local inspect = require "kiwi.turtle.inspect"
local isHome = require "kiwi.turtle.is-home"
local locate = require "kiwi.turtle.locate"
local move = require "kiwi.turtle.move"
local navigate = require "kiwi.turtle.navigate"
local orientate = require "kiwi.turtle.orientate"
local turn = require "kiwi.turtle.turn"

local Turtle = {
    dig = dig,
    face = face,
    inspect = inspect,
    isHome = isHome,
    locate = locate,
    move = move,
    navigate = navigate,
    turn = turn,
    orientate = orientate
}

return Turtle
