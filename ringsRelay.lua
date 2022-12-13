----------------- Configuration --------------------------------

-- List of Players that are allowed to interact with this program
local AllowedList = {}

-- Custom name:
-- a custom name to set for this set of rings
local CustName = nil

-- Rings Type:
-- 0 for Goa'uld
-- 1 for Ori
local Type = 0

-- Comms port:
-- the port the system will use for communication
local Port = 1

-- System code:
-- the code the system will use to identify sets fo rings that are in the system
local SysCode = "Alpha"


local c = require("component")
local tr = c.transportrings
local m = c.modem
local serialization = require("serialization")
local event = require("event")
local OwnName = ""

m.setWakeMessage('', true)
m.open(Port)
m.setStrength(200)
local NearAddresses = {}
local AddressChain = {}
local LastSignal = {ADDRESS = nil, SIGNAL = nil}
local Locked = false

local KnownRings = {}


local function SerializeAddress(address)
    local serial = ""
    for i, glyph in ipairs(address) do
        serial = serial .. glyph .. ", "
    end
    print (serial)
    return serial
end

local OwnAddress = ""

if Type == 1 then
    OwnAddress = SerializeAddress(tr.getAddress().ORI)
elseif Type == 0 then
    OwnAddress = SerializeAddress(tr.getAddress().GOAULD)
else
    print("Unknown address type")
    os.exit()
end

function SetRingsID()
    local name = tr.getName()
    if table.contains({"", "RESET"}, name) then
        if CustName == nil then
            tr.setName(SysCode .. "|" .. m.address)
        else
            tr.setName(SysCode .. "|" .. CustName)
        end
    end
    OwnName = tr.getName()
end

local function Reset()
    AddressChain = {}
    Locked = false
end

function table.index(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return i
        end
    end
    return nil
end

function table.contains(array, value)
    for i, v in ipairs(array) do
        if v == value then
            return true
        end
    end
    for k, v in pairs(array) do
        if k == value then
            return true
        end
    end
    return false
end

function table.len(array)
    local len = #array
    if len == 0 then
        for k, v in pairs(array) do
            len = len + 1
        end
    end
    return len
end

local function RelayData(...)
    m.broadcast(Port, ...)
end

local function BFS(node, goal)
    local visited = {}
    local queue = {}
    local path = {}

    table.insert(queue, node)
    table.insert(visited, node)
    print(serialization.serialize(queue))

    print( serialization.serialize(KnownRings))
    while #queue > 0 do
        print("looping")
        local working = {queue[1]}
        print(serialization.serialize(working))
        print(serialization.serialize(KnownRings[working[1]]))
        if #KnownRings[working[1]].NEAR > 0 then
            for i, neighbour in ipairs(KnownRings[working[1]].NEAR) do
                if not table.contains(visited, neighbour) then
                    visited[neighbour] = working
                    table.insert(queue, neighbour)
                end
            end
        else
            print("ERROR data for", working, "Missing")
        end
        print("for loop completed")
        table.remove(queue, 1)
        if table.contains(visited, goal) then
            queue = {}
            print("finished traversing")
        end
    end
    print(serialization.serialize(queue))
    print(serialization.serialize(visited))
    local atStart = false
    local reversePath = {}
    table.insert(reversePath, goal)
    while not atStart do
        table.insert(reversePath, visited[reversePath[#reversePath]][1])
        if reversePath[#reversePath] == node then
            print("Found correct reverse path")
            atStart = true
        end
        print(reversePath[#reversePath])
        os.sleep()
    end
    print(serialization.serialize(reversePath))
    for i = #reversePath, 1, -1 do
        print("found correct path")
        table.insert(path, reversePath[i])
    end
    return path
end

local function GetNearby()
    local temp_near = tr.getAvailableRings()
    local tempAdds = tr.getAvailableRingsAddresses()
    NearAddresses = {}
    for i, address in ipairs(tempAdds) do
        if Type == 0 then
            table[temp_near[address.GOAULD]] = address.GOAULD
        elseif Type == 1 then
            table[temp_near[address.ORI]] = address.ORI
        end
    end
end

local function DialAddress(address)
    local addressUnSed, a = serialization.unserialize("{\""..
        address:gsub(", ", "\", \"").. "\"}")
    if #addressUnSed < 4 then
        print(addressUnSed)
        return nil
    end
    table.remove(addressUnSed, 5)
    print("Dialing:")
    for i, v in ipairs(addressUnSed)do
        print(v)
        tr.addSymbolToAddress(Type, v)
    end
    print(tr.addSymbolToAddress(Type, 5))

end

local function BounceBack(index)
    event.pull("transportrings_teleport_start")
    event.pull("transportrings_teleport_finish")
    print("Bouncing")
    DialAddress(NearAddresses[AddressChain[index-1]])
end

local function TransportRelay(data)
    print("relaying")
    AddressChain = data[2]
    local index = table.index(AddressChain, OwnName)
    if index > 1 then
        event.pull("transportrings_teleport_finish")
    end
    DialAddress(NearAddresses[AddressChain[index+1]])
    event.pull("transportrings_teleport_start")
    if index > 1 and index < #AddressChain then
        BounceBack(index)
    else
        m.broadcast(1, "Complete")
    end
end

local function AddAddressToKnown(data)
    if not table.contains(KnownRings, data[#data]) then
        if table.len(serialization.unserialize(data[3])) < 1 then
            print("ERROR rings:", data[#data], "has no near rings")
            return nil
        end
        KnownRings[data[#data]] = {}
        KnownRings[data[#data]].NEAR = serialization.unserialize(data[3])
        KnownRings[data[#data]].ADDRESS = data[2]
    end
end

local function GetNetwork()
    print("Getting the network")
    m.broadcast(1, "Gimme")
end

local function ModemMessageHandler(ev, selfAdd, originAdd, port, distance, ...)
    local data = {...} -- select("#",  ...)
    if originAdd == LastSignal.ADDRESS and data[1] == LastSignal.SIGNAL then
        return nil
    else
        LastSignal.ADDRESS = originAdd
        LastSignal.SIGNAL = data[1]
    end
    print(serialization.serialize(data))
    if data[1] == "Collect" then
        AddAddressToKnown(data)
        -- print(serialization.serialize(KnownRings))
    elseif data[1] == "Gimme" then
        local nearAddressesSerial = serialization.serialize(NearAddresses)
        print(nearAddressesSerial)
        print(m.broadcast(1, "Collect", OwnAddress, nearAddressesSerial, OwnName))
    elseif data[1] == "Transport" then
        Locked = true
        TransportRelay(data)
    elseif data[1] == "Complete" then
        Reset()
    elseif data[1] == "getNetwork" then
        GetNetwork()
    elseif data[1] == "startRelay" then
        if not table.contains(KnownRings, data[2]) then
            print(data[2], "not in known rings")
            return nil
        end
        print(KnownRings[data[2]])
        local route = BFS(OwnAddress, data[2])
        print(m.broadcast(1, "Transport", serialization.serialize(route)))
        TransportRelay(route)
    end
    if distance > 0.9*m.getStrength() then
        RelayData(data)
    end
end

local function MainLoop()
    SetRingsID()
    GetNearby()
    AddAddressToKnown(
        {"", OwnAddress,
        serialization.serialize(NearAddresses),
        OwnName})
    print(serialization.serialize(KnownRings))
    local loop = true
    while loop do
        ModemMessageHandler(event.pull("modem_message"))
    end
end

MainLoop()