SOUTH, WEST, NORTH, EAST, UP, DOWN = 0, 1, 2, 3, 4, 5
_G["SOUTH"] = SOUTH
_G["WEST"] = WEST
_G["NORTH"] = NORTH
_G["EAST"] = EAST
_G["UP"] = UP
_G["DOWN"] = DOWN

ORIENTATIONS = {
    [SOUTH] = "south",
    [WEST] = "west",
    [NORTH] = "north",
    [EAST] = "east",
    [UP] = "up",
    [DOWN] = "down",
    ["Deltas"] =
    {
        [SOUTH] = vector.new(0,0,1),
        [WEST] = vector.new(-1,0,0),
        [NORTH] = vector.new(0,0,- 1),
        [EAST] = vector.new(1,0,0),
        [UP] = vector.new(0,1,0),
        [DOWN] = vector.new(0,- 1,0),
        ["0,0,1"] = SOUTH,
        ["-1,0,0"] = WEST,
        ["0,0,-1"] = NORTH,
        ["1,0,0"] = EAST,
        ["0,1,0"] = UP,
        ["0,-1,0"] = DOWN
    }
}

_G["ORIENTATIONS"] = ORIENTATIONS

if (turtle) then
    FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM = 0, 1, 2, 3, 4, 5
else
    FRONT, RIGHT, BACK, LEFT, TOP, BOTTOM = 0, 3, 2, 1, 4, 5
end

_G["FRONT"] = FRONT
_G["RIGHT"] = RIGHT
_G["BACK"] = BACK
_G["LEFT"] = LEFT
_G["TOP"] = TOP
_G["BOTTOM"] = BOTTOM

SIDES = {
    [FRONT] = "front",
    ["front"] = FRONT,
    [LEFT] = "left",
    ["left"] = LEFT,
    [BACK] = "back",
    ["back"] = BACK,
    [RIGHT] = "right",
    ["right"] = RIGHT,
    [TOP] = "top",
    ["top"] = TOP,
    [BOTTOM] = "bottom",
    ["bottom"] = BOTTOM
}

_G["SIDES"] = SIDES