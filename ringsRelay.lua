----------------- Declarations ---------------------------------

local c = require("component")
if not c.isAvailable("transportrings") then
    print("Transport rings are required for the operation of this program")
    os.exit()
end
local tr = c.transportrings
local m = c.modem
local serialization = require("serialization")
local event = require("event")
local fs = require("filesystem")
local conf = require("rrs.conf")
local BFS = require("route").BFS
local moreTable = require("moreTable")

local events = {}
local OwnName = ""
local logPath = ""

m.setWakeMessage('', true)
m.open(conf.Port)
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

if conf.Type == 1 then
    OwnAddress = SerializeAddress(tr.getAddress().ORI)
elseif conf.Type == 0 then
    OwnAddress = SerializeAddress(tr.getAddress().GOAULD)
else
    print("Unknown address type")
    os.exit()
end

local function SetRingsID()
    if moreTable.contains({nil, ""}, conf.CustName) then
        tr.setName(conf.SysCode .. "|" .. m.address)
    else
        tr.setName(conf.SysCode .. "|" .. conf.CustName)
    end
    OwnName = tr.getName()
end

local function time()
    return os.date("%H:%M %d/%m", getRealTime())..""
end

local function log(type, ...)
    local log = fs.open(logPath, "a")
    log:write(time().. " " .. type .. " " .. serialization.serialize(...))
end

local function Reset()
    AddressChain = {}
    Locked = false
    LastSignal.ADDRESS = nil
    LastSignal.SIGNAL = nil
    print("Ready")
end

local function RelayData(...)
    m.broadcast(conf.Port, ...)
end

local function GetNearby()
    local temp_near = tr.getAvailableRings()
    local tempAdds = tr.getAvailableRingsAddresses()
    NearAddresses = {}
    for i, address in ipairs(tempAdds) do
        if conf.Type == 0 then
            NearAddresses[temp_near[address.GOAULD]] = address.GOAULD
        elseif conf.Type == 1 then
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
        tr.addSymbolToAddress(conf.Type, v)
    end
    print(tr.addSymbolToAddress(conf.Type, 5))

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
    if conf.logging.relays then
        log("relay", AddressChain)
    end
end

local function TransportRelay(AddressChain)
    print("relaying")
    local index = moreTable.index(AddressChain, OwnName)
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
    if index == #AddressChain then
        if conf.logging.endings then
            log("end", AddressChain)
        end
    end
end

local function AddAddressToKnown(data)
    -- if not moreTable.contains(KnownRings, data[#data]) then
    if #moreTable.keys(serialization.unserialize(data[3])) < 1 then
        print("ERROR rings:", data[#data], "has no near rings")
        return nil
    end
    KnownRings[data[#data]] = {}
    KnownRings[data[#data]].NEAR = serialization.unserialize(data[3])
    KnownRings[data[#data]].ADDRESS = data[2]
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
    elseif data[1] == "disabled" then
        KnownRings = {}
        AddAddressToKnown({"", OwnAddress, serialization.serialize(NearAddresses), OwnName})
        GetNetwork()
    elseif data[1] == "Transport" then
        Locked = true
        TransportRelay(serialization.unserialize(data[2]))
    elseif data[1] == "Complete" then
        Reset()
    elseif data[1] == "getNetwork" then
        if moreTable.contains(conf.AllowedAddressList, originAdd) then
            print("Relay was activated from an authorized address(\"" .. originAdd .. "\")")
        elseif #conf.AllowedAddressList > 0 then
            return nil
        end
        GetNetwork()
    elseif data[1] == "startRelay" then
        if moreTable.contains(conf.AllowedAddressList, originAdd) then
            print("Relay was activated from an authorized address(\"" .. originAdd .. "\")")
        elseif #conf.AllowedAddressList > 0 then
            Reset()
            return nil
        end
        if distance > 5 then
            print("message sent from too great a distance (more than 5 blocks away)")
            Reset()
            return nil
        elseif not moreTable.contains(KnownRings, data[2]) then
            print(data[2], "not in known rings")
            return nil
        elseif data[2] == OwnName then
            print("you can't transport to the location you are already at")
            return nil
        end
        print(KnownRings[data[2]])
        local route = BFS(OwnName, data[2], KnownRings)
        if conf.logging.initiations then
            log("initiation", originAdd, route)
        end
        m.broadcast(1, "Transport", serialization.serialize(route))
        TransportRelay(route)
    end
    if distance > 0.9*m.getStrength() then
        RelayData(data)
    end
end



local function MainLoop()
    for i, v in ipairs(conf.AllowedPlayerList) do
        table.insert(conf.AllowedAddressList, "unv-dialer-" .. v)
    end
    SetRingsID()
    GetNearby()
    AddAddressToKnown({"", OwnAddress, serialization.serialize(NearAddresses), OwnName})
    if conf.GetNetworkOnBoot then
        GetNetwork()
    end
    local loop = true
    events.insert( event.listen("interrupted", function ()
        loop = false
    end))

    if conf.logging.general then
        if not fs.isDirectory(conf.logging.path) then
            fs.makeDirectory(conf.logging.path)
        end
        logPath = fs.concat(conf.logging.path, time())
        local log = fs.open(logPath, "w")
        log:close()
    end
    while loop do
        ModemMessageHandler(event.pull("modem_message"))
    end
end



MainLoop()
for e in ipairs(events) do
    event.cancel(e)
end
m.close(conf.Port)