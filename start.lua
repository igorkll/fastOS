local event = require("event")
local term = require("term")
local computer = require("computer")
local process = require("process")
local fs = require("filesystem")
local md5 = require("md5")
local su = require("superUtiles")

---------------------------------------------------------------

process.info().data.signal = function() end

local createFolders = {"/data", "/readonlyData", "/soft", "/appData", "/settings"}
for i, value in ipairs(createFolders) do
    if not fs.exists(value) then
        fs.makeDirectory(value)
    end
end
---------------------------------------------------------------

if fs.exists("/settings/password.cfg") then
    if not term.isAvailable() then computer.shutdown() end
    local data = su.getFile("/settings/password.cfg")
    while true do
        term.clear()
        term.write("enter password: ")
        local userInput = io.read()
        if not userInput then computer.shutdown() end
        if data == md5.sum(userInput) then
            break
        end
    end
end

if fs.exists("/auto.lua") then os.execute("/auto.lua") end

---------------------------------------------------------------

if not term.isAvailable() then computer.shutdown() end
os.execute("/shell.lua")