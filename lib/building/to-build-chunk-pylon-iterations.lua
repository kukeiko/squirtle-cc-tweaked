local Utils = require "lib.tools.utils"

---@param materials string[]
---@param storageStock ItemStock
---@param numShulkers integer
---@param maxLayers integer
---@return BuildChunkPylonIteration[]
return function(materials, storageStock, numShulkers, maxLayers)
    ---@type ItemStock
    local openStock = {}

    for _, material in ipairs(materials) do
        openStock[material] = storageStock[material]
    end

    local remainingLayers = maxLayers
    -- [todo] ❌ numShulkers was 4, but still managed to want 5x shulkers when requiring the items to build the chunk
    local availableSlots = 27 * numShulkers
    local remainingSlots = availableSlots
    local requiredSlots = (14 * 14) / 64
    ---@type BuildChunkPylonIteration[]
    local iterations = {}
    ---@type BuildChunkPylonIteration
    local iteration = {layers = 0, stock = {}, materials = {}}

    for _, material in ipairs(materials) do
        while (openStock[material] or 0) > 0 and remainingLayers > 0 do
            if remainingSlots < requiredSlots then
                -- start new iteration as there not enough slots available to build another layer
                table.insert(iterations, iteration)
                iteration = {layers = 0, stock = {}, materials = {}}
                remainingSlots = availableSlots
            end

            local carryableQuantity = math.min(openStock[material] or 0, remainingSlots * 64)
            local layersOfMaterial = math.min(remainingLayers, math.floor(carryableQuantity / (14 * 14)))
            local materialQuantity = layersOfMaterial * (14 * 14)

            if materialQuantity == 0 then
                break
            end

            iteration.layers = iteration.layers + layersOfMaterial
            iteration.stock[material] = (iteration.stock[material] or 0) + materialQuantity

            if not Utils.contains(iteration.materials, material) then
                table.insert(iteration.materials, material)
            end

            remainingLayers = remainingLayers - iteration.layers
            remainingSlots = remainingSlots - math.ceil(materialQuantity / 64)
            openStock[material] = openStock[material] - materialQuantity
        end
    end

    if iteration.layers > 0 then
        table.insert(iterations, iteration)
    end

    return iterations
end
