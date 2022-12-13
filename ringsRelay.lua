----------------- Configuration --------------------------------

-- List of Players that are allowed to interact with this
-- program
local AllowedPlayerList = {}

-- List of specific modem addresses that are allowed to interact
-- with this program
-- if message is from one of these addresses AllowedPlayerList
-- will be disregarded
local AllowedAddressList = {}

-- if both allow lists are empty they will not be applied

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
-- the code the system will use to identify sets fo rings that
-- are in the system
local SysCode = "Alpha"

----------------- Declarations ---------------------------------

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

----------------- function definitions -------------------------

local function SerializeAddress(address)
    local serial = ""
    for i, glyph in ipairs(address) do
        serial = serial .. glyph .. ", "
    end
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

local function SetRingsID()
    if table.contains({nil, ""}, CustName) then
        tr.setName(SysCode .. "|" .. m.address)
    else
        tr.setName(SysCode .. "|" .. CustName)
    end
    OwnName = tr.getName()
end

local function Reset()
    AddressChain = {}
    Locked = false
    print("Ready")
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

function table.keys(array)
    local keys = {}
    for k, v in pairs(array) do
        table.insert(keys, k)
    end
    return keys
end

function table.values(array)
    local values = {}
    for k, v in pairs(array) do
        table.insert(values, v)
    end
    return values
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
    while #queue > 0 do
        local working = {queue[1]}
        local near = table.keys(KnownRings[working[1]].NEAR)
        if #near > 0 then
            for i, neighbour in ipairs(near) do
                if not table.contains(visited, neighbour) then
                    visited[neighbour] = working
                    table.insert(queue, neighbour)
                end
            end
        else
            print("ERROR data for", working, "Missing")
        end
        table.remove(queue, 1)
        if table.contains(visited, goal) then
            queue = {}
        end
    end
    local atStart = false
    local reversePath = {}
    table.insert(reversePath, goal)
    while not atStart do
        table.insert(reversePath, visited[reversePath[#reversePath]][1])
        if reversePath[#reversePath] == node then
            atStart = true
        end
        os.sleep()
    end
    for i = #reversePath, 1, -1 do
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
            NearAddresses[temp_near[address.GOAULD]] = address.GOAULD
        elseif Type == 1 then
            NearAddresses[temp_near[address.ORI]] = address.ORI
        end
    end
end

local function DialAddress(address)
    local addressUnSed, a = serialization.unserialize("{\""..
        address:gsub(", ", "\", \"").. "\"}")
    if #addressUnSed < 4 then
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

local function BounceBack(index, AddressChain, final)
    if index < final - 1 then
        event.pull("transportrings_teleport_start")
    end
    event.pull("transportrings_teleport_finish")
    print("Bouncing")
    DialAddress(NearAddresses[AddressChain[index-1]])
    event.pull("transportrings_teleport_finish")
    if index == 2 then
        m.broadcast(1, "Complete")
    end
    Reset()
end

local function TransportRelay(AddressChain)
    print("relaying")
    local index = table.index(AddressChain, OwnName)
    if index == nil then
        print("not me")
        return nil
    end
    if index > 1 and index < #AddressChain then
        event.pull("transportrings_teleport_finish")
    end
    if index < #AddressChain then
        DialAddress(NearAddresses[AddressChain[index+1]])
        event.pull("transportrings_teleport_start")
    end
    if index > 1 and index < #AddressChain then
        BounceBack(index, AddressChain, #AddressChain)
    elseif #AddressChain == 2 then
        m.broadcast(1, "Complete")
        Reset()
    end
end

local function AddAddressToKnown(data)
    if not table.contains(KnownRings, data[#data]) then
        if #table.keys(serialization.unserialize(data[3])) < 1 then
            print("ERROR rings:", data[#data], "has no near rings")
            return nil
        end
        KnownRings[data[#data]] = {}
        KnownRings[data[#data]].NEAR = serialization.unserialize(data[3])
        KnownRings[data[#data]].ADDRESS = data[2]
    end
end

local function GetNetwork()
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
    if data[1] == "Collect" then
        AddAddressToKnown(data)
    elseif data[1] == "Gimme" then
        local nearAddressesSerial = serialization.serialize(NearAddresses)
        m.broadcast(1, "Collect", OwnAddress, nearAddressesSerial, OwnName)
    elseif data[1] == "Transport" then
        Locked = true
        TransportRelay(serialization.unserialize(data[2]))
    elseif data[1] == "Complete" then
        Reset()
    elseif data[1] == "getNetwork" then
        if table.contains(AllowedAddressList, originAdd) then
            print("Relay was activated from an authorized address(\"" .. originAdd .. "\")")
        elseif #AllowedAddressList > 0 then
            return nil
        end
        GetNetwork()
    elseif data[1] == "startRelay" then
        if table.contains(AllowedAddressList, originAdd) then
            print("Relay was activated from an authorized address(\"" .. originAdd .. "\")")
        elseif #AllowedAddressList > 0 then
            Reset()
            return nil
        end
        if distance > 5 then
            print("message sent from too great a distance (more than 5 blocks away)")
            Reset()
            return nil
        elseif not table.contains(KnownRings, data[2]) then
            print(data[2], "not in known rings")
            return nil
        elseif data[2] == OwnName then
            print("you can't transport to the location you are already at")
            return nil
        end
        print(KnownRings[data[2]])
        local route = BFS(OwnName, data[2])
        m.broadcast(1, "Transport", serialization.serialize(route))
        TransportRelay(route)
    end
    if distance > 0.9*m.getStrength() then
        RelayData(data)
    end
end

local function MainLoop()
    for i, v in ipairs(AllowedPlayerList) do
        table.insert(AllowedAddressList, "unv-dialer-" .. v)
    end
    SetRingsID()
    GetNearby()
    AddAddressToKnown(
        {"", OwnAddress,
        serialization.serialize(NearAddresses),
        OwnName})
    local loop = true
    while loop do
        ModemMessageHandler(event.pull("modem_message"))
    end
end

MainLoop()