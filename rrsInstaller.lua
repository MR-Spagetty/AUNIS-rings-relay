local versions = require("rrsVersions")
local shell = require("shell")
local c = require("component")
if c.isAvailable("internet") then
shell.execute("wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/rrsVersions.lua /home/rrsGitVersions.lua")

local GitVersions = require("/home/rrsGitVersions")

local updated = false
for comp, GitVersion in pairs(GitVersions) do
    if versions[comp] < GitVersion then
        if shell.execute(GitVersions[comp].link .. " /RRS/" .. comp .. ".lua")
        then updated = true
        else print("one or more updates failed attempting to run the prgram may haev undesired results") os.exit() end
    end
    if updated then shell.execute("wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/rrsVersions.lua /RRS/rrsVersions.lua") end
end

end
shell.execute("/RRS/ringsRelay")
