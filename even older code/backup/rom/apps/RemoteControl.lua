local RemoteControl = { }

--- <summary>
--- </summary>
--- <returns type="RemoteControl"></returns>
function RemoteControl.new(unit)
    local instance = { }
    setmetatable(instance, { __index = RemoteControl })

    instance:ctor(unit)

    return instance
end

function RemoteControl:ctor(unit)
    self._unit = Squirtle.Unit.as(unit)
end

function RemoteControl:run()
    local terminal = Kevlar.Terminal.new()
    local header = terminal:sub(1, 1, "*", 2)
    local content = terminal:sub(1, 3, "*", "*")
    local wizard = Kevlar.Sync.Wizard.new(content)
    local header = Kevlar.Header.new("RemoteControl", "-", terminal:sub(1, 1, "*", 2))
    
    header:draw()

    self._networking = Components.Networking.get(self._unit)
    local adapter = self._networking:getWirelessAdapter()

    if (self._unit:isTurtle()) then
        local server = Unity.Server.new(adapter, 64)
        content:write(1, 1, adapter:getAddress())
        server:wrap(self._unit, { "turn", "move", "dig" })

        MessagePump.pull("key")
        server:close()
    elseif (self._unit:isPocket()) then
        local num = wizard:getInt("How many?", 1, 64)
        local clients = { }

        for i = 1, num do
            local address = wizard:getString("Address?")
            local client = Unity.ClientProxy.new(adapter, address, 64)
            table.insert(clients, client)
        end

        print("Operational!")
        self:loop(clients)
    end
end

function RemoteControl:loop(clients)
    while (true) do
        local key = MessagePump.pull("key")

        for i = 1, #clients do
            local turtle = clients[i]

            -- left and right is inverted at turtle
            if (key == keys.a) then
                turtle:turn(RIGHT)
            elseif (key == keys.d) then
                turtle:turn(LEFT)
            elseif (key == keys.w) then
                turtle:move(FRONT)
            elseif (key == keys.s) then
                turtle:move(BOTTOM)
            elseif (key == keys.space) then
                turtle:move(TOP)
            elseif (key == keys.f) then
                turtle:dig(FRONT)
            elseif (key == keys.r) then
                turtle:dig(TOP)
            elseif (key == keys.v) then
                turtle:dig(BOTTOM)
            elseif (key == keys.q) then
                return
            end
        end
    end
end

if (Apps == nil) then Apps = { } end
Apps.RemoteControl = RemoteControl