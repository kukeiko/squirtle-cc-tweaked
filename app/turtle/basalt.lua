while true do
    if turtle.getItemCount(16) == 64 then
        print("All done!")
        break
    end

    turtle.dig()
end
