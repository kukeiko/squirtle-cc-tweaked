Scripts = { }

--- <summary>
--- file : file name
--- </summary>
--- <returns type="Scripts"></returns>
function Scripts.load(path)
    if (not fs.exists(path)) then
        error("File not found: " .. path)
    end

    local file, parseError = loadfile(path)

    if (file) then
        setfenv(file, _G)
        file()
    else
        error("File parse error: " .. parseError)
    end
end