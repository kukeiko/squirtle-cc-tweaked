local Utils = require "lib.tools.utils"

---@param materials string[]
---@param storageStock ItemStock
---@param numShulkers integer
---@return BuildChunkPylonIteration[]
return function(materials, storageStock, numShulkers)
    ---@type ItemStock
    local openStock = {}

    for _, material in ipairs(materials) do
        openStock[material] = storageStock[material]
    end

    local remainingSlots = 27 * numShulkers
    local requiredSlots = (14 * 14) / 64
    ---@type BuildChunkPylonIteration[]
    local iterations = {}

    ---@type BuildChunkPylonIteration
    local iteration = {layers = 0, stock = {}, materials = {}}

    for _, material in ipairs(materials) do
        while openStock[material] or 0 > 0 do
            if remainingSlots < requiredSlots then
                table.insert(iterations, iteration)
                iteration = {layers = 0, stock = {}, materials = {}}
                remainingSlots = 27 * numShulkers
            end

            local carriableQuantity = math.min(openStock[material] or 0, remainingSlots * 64)
            local layersOfMaterial = math.floor(carriableQuantity / (14 * 14))
            local materialQuantity = layersOfMaterial * (14 * 14)
            -- using full chunk width/depth to ensure we're not rebuilding the chunk taller than it was
            local subtractedMaterialQuantity = layersOfMaterial * (16 * 16)

            if materialQuantity == 0 then
                break
            end

            iteration.layers = iteration.layers + layersOfMaterial
            iteration.stock[material] = (iteration.stock[material] or 0) + materialQuantity

            if not Utils.contains(iteration.materials, material) then
                table.insert(iteration.materials, material)
            end

            remainingSlots = remainingSlots - (materialQuantity / 64)
            openStock[material] = openStock[material] - subtractedMaterialQuantity
        end
    end

    if iteration.layers > 0 then
        table.insert(iterations, iteration)
    end

    return iterations
end
