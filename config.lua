local config = {
----------------- Configuration Options--------------------------------

-- List of Players that are allowed to interact with this
-- program
AllowedPlayerList = {},

-- List of specific modem addresses that are allowed to interact
-- with this program
-- if message is from one of these addresses AllowedPlayerList
-- will be disregarded
AllowedAddressList = {},

-- if both allow lists are empty they will not be applied

-- Custom name:
-- a custom name to set for this set of rings
CustName = "",

-- Rings Type:
-- 0 for Goa'uld
-- 1 for Ori
Type = 0,

-- Get Network on boot:
-- whether or not to get the relay network on boot
-- you will likly only haev to set this to true on one relay
GetNetworkOnBoot = false,

-- Comms port:
-- the port the system will use for communication
Port = 1,

-- System code:
-- the code the system will use to identify sets fo rings that
-- are in the system
SysCode = "Alpha",

-- Logging:
-- whether or not the system will log various actions
logging = {
    -- if this node is the beginning of the route
    initiations = true,
    -- if the route passed through this node
    relays = true,
    -- if this node is the end of the route
    endings = true,
    -- where the logs will be saved
    path = "/home/rrsLogs"
}
}

config.logging.general = config.logging.initiations or config.logging.relays or config.logging.endings

return config