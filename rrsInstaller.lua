local versions = require("rrsVersions")
local shell = require("shell")
local c = require("component")
local fs = require("filesystem")
if c.isAvailable("internet") then
shell.execute("wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/rrsVersions.lua /home/rrsGitVersions.lua")




local GitVersions = require("/home/rrsGitVersions")

local updated = false
for comp, GitVersion in pairs(GitVersions) do
    if (versions[comp] < GitVersion) + (arg[1] == "--force") then
        if shell.execute(GitVersions[comp].link .. " /RRS/" .. comp .. ".lua")
        then updated = true
            for _, line in ipairs(GitVersions[comp].changelog) do
            print(line)
            end
        else print("one or more updates failed attempting to run the prgram may haev undesired results") os.exit() end
    end
    if updated
    then shell.execute("wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/rrsVersions.lua /RRS/rrsVersions.lua")
    else print("if you want to force the program to install the current github version please use \"rss --force\"")
    end
end
end
if not fs.exists("/bin/rrs.lua") then
local rrsBinFile = [[
shell = require("shell")
filesystem = require("filesystem")
local args, opts = shell.parse(...)
if filesystem.exists("/RRS/rrsInstaller.lua") then
    local options = "-"
    for k,v in pairs(opts) do options = options..tostring(k) end
    shell.execute("/RRS/rrsInstaller.lua "..options)
else
    io.stderr:write("Rings Relay System is Not Correctly Installed\n")
end
]]
local file = io.open("/bin/rrs.lua", "w")
file:write(rrsBinFile)
file:close()
print("you can now run Rings relay system with \"rrs\" in the shell")
end
shell.execute("/RRS/ringsRelay")
