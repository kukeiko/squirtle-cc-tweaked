local Digging = { }

--- <summary>
--- Creates the optimal path for a turtle to dig out a cuboid, where a and b designate the opposing edge points of a cuboid.
--- </summary>
--- <returns type="???"></returns>
Digging.cuboid = function (a, b)
    local numLayers = math.abs(a.y - b.y)
    
    -- #layers for digging front, up & down
    local numTriLayers = math.floor(numLayers / 3)

    -- #layers for digging front & down
    local numBiLayers = math.floor((numLayers -(numTriLayers * 3)) / 2)

    -- #layers for digging front
    local numOneLayers = numLayers -(numBiLayers * 2) -(numTriLayers * 3)

    local delta = b - a

    -- directional unit deltas
    local unitDeltas = {
        x = delta:unitX(),
        y = delta:unitY(),
        z = delta:unitZ()
    }

    for y = 1, numTriLayers do
        
    end
end

if (Scout == nil) then Scout = { } end
Scout.Digging = Digging