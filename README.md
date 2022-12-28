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

## Wireless commands

- ```getNetwork```

   Tells a node to get all tet available rings
- ```startRelay,<NodeID>```

   Tells a node to start tth relay to go to the specified node.  
   Nodes will ignore this signal if it was received from more than 5 blocks away.  
   NodeID will be either of one of the formats:

   - ```<SysCode>|<modem address>```
   - ```<SysCode>|<CustName>```
