-- 0.1.0
local sides = require("sides")

sides.turn = {
    left = {
        [0] = 0,
        [1] = 1,
        [2] = 4,
        [3] = 5,
        [4] = 3,
        [5] = 2,
        [6] = 6
    },
    right = {
        [0] = 0,
        [1] = 1,
        [2] = 5,
        [3] = 4,
        [4] = 2,
        [5] = 3,
        [6] = 6
    },
    around = {
        [0] = 1,
        [1] = 0,
        [2] = 3,
        [3] = 2,
        [4] = 5,
        [5] = 4,
        [6] = 6
    }
}

return sides