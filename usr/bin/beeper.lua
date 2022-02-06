local gui = require("gui_new").create(25 + 10 + 9, 5)
local midi = require("midi2")
local fs = require("filesystem")
local event = require("event")
local component = require("component")
local computer = require("computer")
local shell = require("shell")

-----------------------------------------------

local args = shell.parse(...)
if not args[1] then print("file not found") return end
local path = shell.resolve(args[1])
if fs.isDirectory(path) then print("is directory") return end
if not fs.exists(path) then print("not exists") return end

local tones = {}
local device = {}

if component.isAvailable("beep") then
    function device.flush()
        component.beep.beep(tones)
        tones = {}
    end
    device[1] = function(n, d) tones[n] = d end
else
    device[1] = function(n, d) computer.beep(n, d) end
end

local obj
local objthread

obj = midi.create(fs.concat(path, selected), device)
obj.min = 20
obj.max = 2000

-----------------------------------------------

local main = gui.createScene()
local playButton = main.createButton(1, 1, 8, 1, "play", nil, nil, nil, nil, nil, nil, function()
    if objthread then objthread:kill() objthread = nil end 
    if obj and not objthread then objthread = obj.createThread(true) end
end)
local stopButton = main.createButton(1, 2, 8, 1, "stop", nil, nil, nil, nil, nil, nil, function()
    if objthread then objthread:kill() objthread = nil end
end)

local speed = main.createSeekBar(11, 3, 24, nil, nil, 0.1, 2, 1)
local notespeed = main.createSeekBar(11, 4, 24, nil, nil, 0.1, 2, 1)
local pitch = main.createSeekBar(11, 5, 24, nil, nil, 0.1, 2, 1)

local speedlabel = main.createLabel(1, 3, 10, 1, "speed")
local notespeedlabel = main.createLabel(1, 4, 10, 1, "notespeed")
local pitchlabel = main.createLabel(1, 5, 10, 1, "pitch")

local speedlabelvalue = main.createLabel(25 + 10, 3, 10, 1, "")
local notespeedlabelvalue = main.createLabel(25 + 10, 4, 10, 1, "")
local pitchlabelvalue = main.createLabel(25 + 10, 5, 10, 1, "")

gui.select(main)

-----------------------------------------------

while true do
    local eventData = {event.pull(0.5)}
    gui.uploadEvent(table.unpack(eventData))
    if obj then
        obj.speed = speed.getState()
        obj.noteduraction = notespeed.getState()
        obj.pitch = pitch.getState()
    end
    speedlabelvalue.text = tostring(math.floor(speed.getState() * 9) / 8)
    notespeedlabelvalue.text = tostring(math.floor(notespeed.getState() * 9) / 8)
    pitchlabelvalue.text = tostring(math.floor(pitch.getState() * 9) / 8)
    speedlabelvalue.draw()
    notespeedlabelvalue.draw()
    pitchlabelvalue.draw()
end