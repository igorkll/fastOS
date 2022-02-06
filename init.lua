do
  local addr, invoke = computer.getBootAddress(), component.invoke
  local function loadfile(file)
    local handle = assert(invoke(addr, "open", file))
    local buffer = ""
    repeat
      local data = invoke(addr, "read", handle, math.huge)
      buffer = buffer .. (data or "")
    until not data
    invoke(addr, "close", handle)
    return load(buffer, "=" .. file, "bt", _G)
  end
  loadfile("/lib/core/boot.lua")(loadfile)
end

local fs = require("filesystem")
local event = require("event")
local term = require("term")
local computer = require("computer")

-----------------------------------

local autorunspath = "/autoruns"
local systemautoruns = fs.concat(autorunspath, "system")
local userautoruns = fs.concat(autorunspath, "user")

-----------------------------------

if fs.exists(systemautoruns) then
    for data in fs.list(systemautoruns) do
        os.execute(fs.concat(systemautoruns, data))
    end
end

if fs.exists(userautoruns) then
    for data in fs.list(userautoruns) do
        os.execute(fs.concat(userautoruns, data))
    end
end

if fs.exists("/start.lua") then 
  os.execute("/start.lua")
elseif fs.exists("/.start.lua") then 
  os.execute("/.start.lua")
elseif fs.exists("/autorun.lua") then 
  os.execute("/autorun.lua")
elseif fs.exists("/.autorun.lua") then 
  os.execute("/.autorun.lua")
end

-----------------------------------

print("error press enter to shutdown...")
event.pull("key_down", term.keyboard(), nil, 28)
computer.shutdown()