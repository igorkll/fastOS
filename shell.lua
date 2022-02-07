local su = require("superUtiles")
local fs = require("filesystem")
local event = require("event")
local term = require("term")
local process = require("process")
local unicode = require("unicode")
local computer = require("computer")
local component = require("component")
local keyboard = require("keyboard")
local shell = require("shell")
local originalInterrupt = process.info().data.signal
local gui = require("gui_new").create()

------------------------------------------

local gpu = gui.gpu
gui.closeallow = false
local rx, ry = gpu.getResolution()

------------------------------------------

local function executeInZone(wait, func, ...)
    local oldScene = gui.getScene()
    local oldInterrupt = process.info().data.signal

    gui.select(0)
    local oldb = gpu.setBackground(0)
    local oldf = gpu.setForeground(0xFFFFFF)
    gpu.setResolution(gpu.maxResolution())
    local rx, ry = gpu.getResolution()
    gpu.fill(1, 1, rx, ry, " ")

    process.info().data.signal = originalInterrupt
    local out = {pcall(func, ...)}
    if not out[1] then print(out[2] or "unkown") end
    process.info().data.signal = oldInterrupt

    if wait then
        print("press enter to continue...")
        while true do
            local eventName, uuid, _, code = event.pull()
            if eventName == "key_down" and uuid == term.keyboard() and code == 28 then
                break
            end
        end
    end

    gpu.setBackground(oldb)
    gpu.setForeground(oldf)

    gui.select(oldScene or 0)
    return table.unpack(out)
end

local function runCommand(command, wait)
    executeInZone(wait, os.execute, command)
end

local function runFile(path, wait, ...)
    executeInZone(wait, shell.execute, path, _ENV, ...)
end

------------------------------------------

local systemFS = fs.get("/").address

local function getFile(fs, path)
    local file, err = fs.open(path)
    if not file then return nil, err end
    local buffer = ""
    while true do
        local read = fs.read(file, math.huge)
        if not read then break end
        buffer = buffer .. read
    end
    fs.close(file)
    return buffer
end

local function getMountPath(address)
    if address == systemFS then
        return "/"
    end
    for proxy, path in fs.mounts() do
        if proxy.address == address then
            return path
        end
    end
end

------------------------------------------

local files = {}

------------------------------------------

local drawIndex = su.generateRandomID()

local main = gui.createScene()
main.createDrawZone(1, 1, rx, ry, function() end, drawIndex)
local logZone = main.createLogZone(1, 1, rx, ry, nil, nil, nil, nil, false)
logZone.autodraw = false

gui.select(main)

------------------------------------------

local function reindex()
    files = {}
    local function add(customFs, path)
        if customFs.exists(path) then
            for _, data in ipairs(customFs.list(path)) do
                local fullPath = fs.concat(path, data)
                if customFs.isDirectory(fullPath) then
                    add(customFs, fullPath)
                else
                    if customFs.size(fullPath) <= (computer.freeMemory() / 4) then
                        local fullPath = fs.concat(getMountPath(customFs.address), fullPath)
                        local ok = true
                        for i = 1, #files do
                            if fs.name(files[i]) == fs.name(fullPath) then
                                ok = false
                                break
                            end
                        end
                        if ok then
                            files[#files + 1] = fullPath
                        end
                    end
                end
            end
        end
    end
    add(component.proxy(systemFS), "/data")
    add(component.proxy(systemFS), "/soft")
    add(component.proxy(systemFS), "/readonlyData")
    for address in component.list("filesystem") do
        if address ~= systemFS then
            add(component.proxy(address), "/")
        end
    end
    logZone.clear()
    for i = 1, #files do logZone.add(fs.name(files[i])) end
    logZone.draw()
end
reindex()
shell_reindex = reindex

------------------------------------------

local function split(str, sep)
    local parts, count = {}, 1
    for i = 1, unicode.len(str) do
        local char = unicode.sub(str, i, i)
        if not parts[count] then parts[count] = "" end
        if char == sep then
            count = count + 1
        else
            parts[count] = parts[count] .. char
        end
    end
    return parts
end

local function isMainFolder(path, target)
    return unicode.sub(path, 1, unicode.len(target)) == target
end

local function getException(path)
    local path = fs.name(path)
    if not path:find("[^%.]%.[^%.]") then return nil end
    local out = ""
    for data in path:gmatch("[^.]+") do out = data end
    return out
end

local function isSoft(path)
    return isMainFolder(path, "/soft")
end

local function isSystem(path)
    return isMainFolder(path, "/readonlyData")
end

local function isData(path)
    return isMainFolder(path, "/data")
end

local function isExternal(path)
    return isMainFolder(path, "/mnt") or isMainFolder(path, "/tmp")
end

local function fileDescriptor(path)
    local exception = getException(path)
    if exception == "txt" or exception == "log" then
        local dop = "-"
        if isSystem(path) or isSoft(path) then dop = dop .. "r" end
        runFile("edit", false, path, dop)
        return true
    elseif exception == "lua" then
        if isSystem(path) or isSoft(path) then
            runFile(path, false)
            return true
        end
    elseif exception == "pic" then
        local dop = "-f"
        if isSystem(path) or isSoft(path) then dop = dop .. "r" end
        runFile("paint", false, path, dop)
        return true
    elseif exception == "mid" or exception == "midi" then
        runFile("beeper", false, path)
        return true
    elseif fs.exists("/settings/exceptions.cfg") then
        local data = split(su.getFile("/settings/exceptions.cfg"), "\n")
        for i, value in ipairs(data) do
            local programm, exp = table.unpack(split(value, ";"))
            if exp == exception then
                runFile(programm, false, path)
                return true
            end
        end
    end
    return nil, "this file in not supported"
end
shell_fileDescriptor = fileDescriptor

local function enterData(text)
    local ok, out = executeInZone(false, function() term.write(text..": ") return io.read() end)
    return out
end

local function getFileName(text, exception)
    return enterData(text) .. "." .. exception
end

local function rename(path, newname)
    fs.rename(path, fs.concat(fs.path(path), newname))
end

local function selectComponent(message, filter, back)
    local components = {addresses = {}, names = {}}
    for address in component.list(filter) do
        components.addresses[#components.addresses + 1] = address
        components.names[#components.names + 1] = table.concat({address:sub(1, 6), component.proxy(address).getLabel and component.proxy(address).getLabel()})
    end
    if back then components.names[#components.names + 1] = "back" end
    local _, num = gui.menu(message, components.names)
    return components.addresses[num]
end

------------------------------------------

local lastTouchX, lastTouchY

while true do
    local eventData = {event.pull()}
    if eventData[1] == "touch" and eventData[2] == term.screen() then
        lastTouchX = eventData[3]
        lastTouchY = eventData[4]
    end
    if eventData[1] == "key_down" and eventData[2] == term.keyboard() and eventData[4] == 29 then
        local select = gui.menu("menu", {"reboot", "shutdown", "refresh", "wget", "pastebin get", "back"})
        if select == "reboot" then
            computer.shutdown(true)
        elseif select == "shutdown" then
            computer.shutdown()
        elseif select == "refresh" then
            reindex()
        elseif select == "wget" then
            local url = enterData("url")
            if url and url ~= "" then
                local name = enterData("name")
                if name and name ~= "" then
                    if name:find("%/") or name:find("%\\") then
                        gui.splash("/ this unsupported char")
                    else
                        runFile("wget", true, url, fs.concat("/data", name))
                        reindex()
                    end
                end
            end
        elseif select == "pastebin get" then
            local code = enterData("code")
            if code and code ~= "" then
                local name = enterData("name")
                if name and name ~= "" then
                    if name:find("%/") or name:find("%\\") then
                        gui.splash("/ this unsupported char")
                    else
                        runFile("pastebin", true, "get", code, fs.concat("/data", name))
                        reindex()
                    end
                end
            end
        end
    end
    gui.uploadEvent(table.unpack(eventData))
    if eventData[1] == "drawZone" and eventData[2] == "touch" and eventData[3] == drawIndex then
        local posX = eventData[4]
        local posY = eventData[5]
        local text = logZone.strs[posY]
        local select = text
        for i = 1, #files do
            if fs.name(files[i]) == select then select = i break end
            if i == #files then select = nil end
        end
        if select then select = files[select] end
        if text and not (posX <= unicode.len(text)) then select = nil end

        if eventData[6] == 0 then
            if select then
                local ok, err = fileDescriptor(select)
                if not ok then gui.splash(err) end
            end
        elseif eventData[6] == 1 then
            if select then
                local out = gui.context(true, lastTouchX, lastTouchY, {{"upload to pastebin", select and (not isSystem(select)) and (not isSoft(select)) and component.isAvailable("internet")}, {"remove", select and not isSystem(select)}, {"rename", select and not isSystem(select) and not isSoft(select)}, {"import", select and isExternal(select)}, {"export", select and not isSystem(select) and not isSoft(select)}}, true)
                if out == "remove" then
                    if gui.yesno("вы уверены что хотите удалить файл?("..text..")") then
                        fs.remove(select)
                        reindex()
                    end
                elseif out == "rename" then
                    local newname = enterData("new name")
                    if newname and newname ~= "" then
                        local exp = getException(select)
                        if exp then exp = "." .. exp end
                        rename(select, newname .. (exp or ""))
                        reindex()
                    end
                elseif out == "upload to pastebin" then
                    runFile("pastebin", true, "put", select)
                elseif out == "import" or out == "export" then
                    if fs.get(select).isReadOnly() then
                        gui.splash("возозможен "..out.." с readonly диска")
                    else
                        if gui.yesno("вы уверены произвести "..out.."?") then
                            if out == "import" then
                                fs.rename(select, fs.concat("/data", fs.name(select)))
                                reindex()
                            elseif out == "export" then
                                local address = selectComponent("export to", "filesystem", true)
                                if address then
                                    if address ~= systemFS and address ~= fs.get(select).address then
                                        if address ~= computer.tmpAddress() or gui.yesno("export в tmpfs приведет к удаления файла после перезагрузки вы уверенны?") then
                                            local path = getMountPath(address)
                                            fs.rename(select, fs.concat(path, fs.name(select)))
                                            reindex()
                                        end
                                    else
                                        gui.splash("нельзя произвести export на этот диск")
                                    end
                                end
                            end
                        end
                    end
                end
            else
                local out = gui.context(true, lastTouchX, lastTouchY, {{"paint", not select}, {"edit", not select}}, true)
                if out == "edit" or out == "paint" then
                    local name = enterData("name")
                    if name and name ~= "" then
                        local path = fs.concat("/data", name)
                        if out == "edit" then
                            path = path .. ".txt"
                            runFile("edit", false, path)
                        else
                            path = path .. ".pic"
                            runFile("paint", false, path, "-f")
                        end
                        reindex()
                    end
                end
            end
        end
    end
end