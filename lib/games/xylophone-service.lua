local Rpc = require "lib.tools.rpc"

---@class XylophoneService : Service
---@field noteCount integer
local XylophoneService = {name = "xylophone", noteCount = 1, expectedNote = 1}

---@param noteCount integer
function XylophoneService.run(noteCount)
    XylophoneService.noteCount = noteCount
    XylophoneService.expectedNote = 1
    redstone.setOutput("right", false)
    redstone.setOutput("top", false)
    Rpc.host(XylophoneService)
end

function XylophoneService.reset()
    print("[reset] expected note to 1")
    XylophoneService.expectedNote = 1
end

---@param note integer
function XylophoneService.notePlayed(note)
    local self = XylophoneService

    if note == self.expectedNote then
        print("[played] correct note", note)
        self.expectedNote = self.expectedNote + 1

        if self.expectedNote > self.noteCount then
            XylophoneService.won()
        end
    else
        print(string.format("[played] incorrect note %d, expected %d", note, self.expectedNote))
        self.expectedNote = 1
    end
end

function XylophoneService.won()
    print("[won] players won!")
    os.sleep(1)
    local speaker = peripheral.find("speaker")

    if speaker then
        speaker.playSound("ui.toast.challenge_complete", 2)
    end

    redstone.setOutput("right", true)
    redstone.setOutput("top", true)
    os.sleep(1)
    XylophoneService.reset()
end

return XylophoneService
