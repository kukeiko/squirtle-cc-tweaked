---@class TeleportService : Service
local TeleportService = {name = "teleport"}

local pdaIds = {
    ---@type integer?
    left = nil,
    ---@type integer?
    right = nil,
    ---@type integer?
    top = nil
}

---@param id integer
---@return string?
local function lookupPdaId(id)
    for side, pdaId in pairs(pdaIds) do
        if pdaId == id then
            return side
        end
    end
end

---@param id integer
---@return boolean
function TeleportService.hasPdaId(id)
    return lookupPdaId(id) ~= nil
end

---@param side "left" | "right" | "top"
---@return integer?
function TeleportService.getPdaId(side)
    return pdaIds[side]
end

---@param side "left" | "right" | "top"
---@param id integer?
function TeleportService.setPdaId(side, id)
    pdaIds[side] = id
end

---@param id integer
function TeleportService.activate(id)
    local side = lookupPdaId(id)

    if not side then
        error(string.format("PDA Id %d not associated with a side", id))
    end

    redstone.setOutput(side, true)
    os.sleep(.25)
    redstone.setOutput(side, false)
    local speaker = peripheral.find("speaker")

    if speaker then
        speaker.playSound("block.portal.travel", .5)
    end
end

return TeleportService
