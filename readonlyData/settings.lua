local term = require("term")
local md5 = require("md5")
local fs = require("filesystem")
local su = require("superUtiles")
local event = require("event")
local gui = require("gui_new").create()

-------------------------------------

local function getPassword()
    return su.getFile("/settings/password.cfg")
end

local function setPassword(new)
    return su.saveFile("/settings/password.cfg", md5.sum(new))
end

local function resetPassword()
    fs.remove("/settings/password.cfg")
end

local function input(message)
    local oldScene = gui.getScene()
    gui.select(0)
    term.write(message..": ")
    local read = io.read()
    gui.select(oldScene)
    return read
end

local function enterPassword(message)
    return input(message or "enter password")
end

local function isPassword()
    return fs.exists("/settings/password.cfg")
end

local function checkPassword(message)
    if not isPassword() then return true end
    while true do
        local read = enterPassword(message)
        if not read then return false end
        if md5.sum(read) == getPassword() then return true end
    end
end

-------------------------------------

local main = gui.createScene()
main.createButton(1, 1, 16, 1, "set password", nil, nil, nil, nil, nil, nil, function()
    if checkPassword("enter you password") then
        local new = enterPassword()
        if new then
            local new2 = enterPassword("commit password")
            if new == new2 then
                setPassword(new)
            else
                gui.splash("пароли не совпадают")
            end
        end
    end
end)
main.createButton(1, 2, 16, 1, "reset password", nil, nil, nil, nil, nil, nil, function()
    if checkPassword("enter you password") then
        resetPassword()
    end
end)
gui.select(main)

-------------------------------------

while true do
    local eventData = {event.pull()}
    gui.uploadEvent(table.unpack(eventData))
end