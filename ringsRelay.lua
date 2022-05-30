-- List of Players that are allowed to interact with this program
AllowedList = {}

c = require("component")
tr = c.transportrings
m = c.modem
serialization = require("serialization")
event = require("event")
OwnName = tr.getName()

m.setWakeMessage('', true)
m.open(1)
m.setStrength(200)
NearAddresses = {}
AddressChain = {}
LastSignal = {ADDRESS = nil, SIGNAL = nil}
Locked = false
-- Rings Type:
-- 0 for Goa'uld
-- 1 for Ori
Type = 0


function SerializeAddress(address)
    local serial = ""
    for i, glyph in ipairs(address) do
        serial = serial .. glyph .. ", "
    end
    print (serial)
    return serial
end

if Type == 1 then
    OwnAddress = SerializeAddress(tr.getAddress().ORI)
elseif Type == 0 then
    OwnAddress = SerializeAddress(tr.getAddress().GOAULD)
end

KnownRings = {[OwnAddress] = NearAddresses}

function Reset()
    AddressChain = {}
    Locked = false
end

function indexOf(array, value)
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

function RelayData(...)
    m.broadcast(1, ...)
end

function BFS(node, goal)
    local visited = {}
    local queue = {}
    local path = {}

    table.insert(queue, node)
    table.insert(visited, node)
    print(serialization.serialize(queue))

    print( serialization.serialize(KnownRings))

    while #queue > 0 do
        print("looping")
        local working = queue[1]
        print(serialization.serialize(working), working)
        print(working, serialization.serialize(KnownRings[working]))

        for i, neighbour in ipairs(KnownRings[working].NEAR) do
            if not table.contains(visited, neighbour) then
                visited[neighbour] = working
                table.insert(queue, neighbour)
            end
        end
        print("for loop completed")
        if table.contains(visited, goal) then
            queue = {}
            print("finished traversing")
        else
            table.remove(queue, 1)
        end
    end
    print(serialization.serialize(queue))
    print(serialization.serialize(visited))
    local atStart = false
    local reversePath = {}
    table.insert(reversePath, goal)
    while not atStart do
        table.insert(reversePath, visited[reversePath[#reversePath]])
        if reversePath[#reversePath] == node then
            print("Found correct reverse path")
            atStart = true
        end
    end
    print(serialization.serialize(reversePath))
    for i = #reversePath, 1, -1 do
        print("found correct path")
        table.insert(path, reversePath[i])
    end
    return path
end

function GetNearby()
    local tempAdds = tr.getAvailableRingsAddresses()
    NearAddresses = {}
    for i, address in ipairs(tempAdds) do
        if Type == 0 then
            table.insert(NearAddresses, address.GOAULD)
        elseif Type == 1 then
            table.insert(NearAddresses, address.ORI)
        end
    end
end

function DialAddress(address)
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

function TransportRelay(data)
    print("relaying")
    AddressChain = data[2]
    local index = indexOf(AddressChain, OwnAddress)
    if index > 1 then
        event.pull("transportrings_teleport_finish")
    end
    DialAddress(AddressChain[index+1])
    event.pull("transportrings_teleport_start")
    if index > 1 and index < #AddressChain then
        BounceBack(index)
    else
        m.broadcast(1, "Complete")
    end
end

function BounceBack(index)
    event.pull("transportrings_teleport_start")
    event.pull("transportrings_teleport_finish")
    print("Bouncing")
    DialAddress(AddressChain[index-1])
end

function ModemMessageHandler(ev, selfAdd, originAdd, port, distance, ...)
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
            print(serialization.serialize(data[2]), "not in known rings")
            return nil
        end
        local route = BFS(OwnAddress, data[2])
        print(m.broadcast(1, "Transport", serialization.serialize(route)))
        TransportRelay(route)
    end
    if distance > 0.9*m.getStrength() then
        RelayData(data)
    end
end

function AddAddressToKnown(data)
    if not table.contains(KnownRings, data[2]) then
        if #serialization.unserialize(data[3]) < 1 then
            print("ERROR rings:", data[2], "has no near rings")
            return nil
        end
        KnownRings[data[2]] = {}
        KnownRings[data[2]].NEAR = serialization.unserialize(data[3])
        KnownRings[data[2]].NAME = data[4]
    end
end

function GetNetwork()
    print("Getting teh network")
    m.broadcast(1, "Gimme")
end

function MainLoop()
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