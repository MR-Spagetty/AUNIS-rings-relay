# Rings Relay system

![Program Banner](RRS_Banner_ancient.png "RRS (Rings Relay System)")

Have you ever needed or wanted to travel horizontally with the transport rings from JSG but been halted by the horizontal limit of 20 blocks and didn't want to change the config?

Well look no further than the SpagTech Rings Relay System (RRS for short)

This system is specifically designed to artificially extend the horizontal reach of your transport rings by using other sets of rings as relay points

## Features

- *Automatic* route calculation
- Full swapping of payloads

   as if you were using a normal  
   pair of transport rings
- Access control
- Custom names

   So you don't have to remember  
   the full modem addresses
- Grid identifiers

   *no functional purpose just allows a user  
   to see that a set of rings belongs to  
   a relay system*
- Wireless control

   *The only control option*

## Computer requirements

The **minimum** components needed to run the program are:

- Tier 2 computer case
- Tier 2 CPU
- Tier 2 memory x2
- Tier 2 Wireless network card
- Rings (Any type)

## Installation

To install the Rings Relay System simply put run the command:
```
wget https://raw.githubusercontent.com/MR-Spagetty/AUNIS-rings-relay/main/ringsRelay.lua -f
```
in the shell of the computer you want to install it on.  
recommended optional steps:

- add `ringsRelay` to the `/home/.shrc` file so that it automatically starts with the computer
- set the modem wake message (also recommend setting the wake message to be fuzzy)

## Wireless commands

- ```getNetwork```

   Tells a node to get all the available rings
- ```startRelay,<NodeID>```

   Tells a node to start tth relay to go to the specified node.  
   Nodes will ignore this signal if it was received from more than 5 blocks away.  
   NodeID will be either of one of the formats:

   - ```<SysCode>|<modem address>```
   - ```<SysCode>|<CustName>```
