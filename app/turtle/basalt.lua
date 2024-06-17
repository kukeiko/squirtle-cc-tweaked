while true do
    while turtle.getItemCount(16) == 64 do
        os.sleep(3)
    end

    turtle.dig()
end
