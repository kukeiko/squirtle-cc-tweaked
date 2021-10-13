-- if (Disk.exists("log.txt")) then
--    Disk.move("log.txt", "log-previous.txt")
-- end

MessagePump.on("key", function(key)
    if (key == keys.f5) then
        os.reboot()
    elseif (key == keys.f7) then
        Log.dump()
    end
end , "interrupt")

MessagePump.run( function()
    local unit
    
    if (turtle) then
        unit = Squirtle.Turtle.new()
    elseif (pocket) then
        unit = Squirtle.Tablet.new()
    else
        unit = Squirtle.Computer.new()
    end
    
    unit:load()

    local applist = Apps.AppMenu.new(unit)
    applist:run()
    MessagePump:quit()
    --    if (turtle) then
    --        local t = Squirtle.Turtle.new()
    --        t:load()
    --    elseif (pocket) then
    --        local t = Squirtle.Tablet.new()
    --        t:load()
    --    end

    --    MessagePump:quit()

end , "main")