local shell = require("shell")
local c = require("component")
local fs = require("filesystem")

local workingDir = shell.getWorkingDirectory()
shell.setWorkingDirectory("/RRS")
if c.isAvailable("internet") then
local versions = require("rrsVersions")
shell.setWorkingDirectory("/home")
shell.execute("wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/rrsVersions.lua /home/rrsGitVersions.lua -f")
local GitVersions = require("rrsGitVersions")

local updated = false
local args, opts = shell.parse(...)
for comp, GitVersion in pairs(GitVersions) do
    if versions[comp].version < GitVersion.version or opts.force then
        if shell.execute("wget " .. GitVersions[comp].link .. " /RRS/" .. comp .. ".lua -f")
        then updated = true
            for _, line in ipairs(GitVersions[comp].changelog) do
            print(line)
            end
        else print("one or more updates failed attempting to run the prgram may haev undesired results") os.exit() end
    end
    if updated
    then shell.execute("wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/rrsVersions.lua /RRS/rrsVersions.lua -f")
    else print("if you want to force the program to install the current github version please use \"rss -force\"")
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
shell.setWorkingDirectory(workingDir)
shell.execute("/RRS/ringsRelay")
