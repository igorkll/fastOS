local nano = require("nano")
local term = require("term")

---------------------------------------------------

local function input(message)
    term.write((message or "select")..": ")
    return io.read() or os.exit()
end

local function toboolean(data)
    if data == 0 or data == nil or data == false or data == "false" or data == "0" then return false end
    if data == "true" or data == true or data == 1 or data == "1" then return true end
end

local function wait()
    print("press enter to continue...")
    io.read()
end

---------------------------------------------------


while true do
    term.clear()
    print("1.set pin")
    print("2.get pin")
    print("3.get pins")
    local select = input()
    if select == "1" then
        local pin = tonumber(input("pin"))
        local state = toboolean(input("state"))
        nano.setInput(pin, state)
    elseif select == "2" then
        local pin = tonumber(input("pin"))
        print(nano.getInput(pin))
        wait()
    elseif select == "3" then
        local pinsCount = nano.getTotalInputCount()
        for i = 1, pinsCount do
            print(tostring(i).."."..tostring(nano.getInput(i)))
        end
        wait()
    end
end