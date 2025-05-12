# Monitoring the Tofino Throughputs

This is the code implementing a monitoring strategy based on the eggress pipeline to monitor informations like throughput, queues, IPG, etc from flows and ports. The code keep monitoring all flows and ports, and write this information in the monitoring packets when requested.

## Requisits:
SDE version tested: 9.13, but should work at 9.12.

Python3 and some libraries.

tcpreplay.

## Pre-usage:
Prepare three terminals: one at Tofino, and two at the monitoring server (a server connected directly to the tofino)

Clone the project at both environments.

Set the SDE bash at tofino.


## Usage:



The idea is that you can copy our eggress pipeline code at your code and monitor the informations with our hosts scripts. However, to be able to do it, your ingress pipeline should be able to understand and forward our monitoring packets. The monitoring packets are encapsulated at ethernet (ethertype=0x1234), and self forwarded, what means that there is a field (called port) containing the portID that the packet should be forwarded at the ingress pipeline. So, you should include our monitoring headers (monitor_inst_h and monitor_h), and the parser support at your ingress pipeline, as well with a condition/table to assign the eggress port.


### Starting by our code:

As an preliminar test, you can use our own code that is monitoring all flows, and just have a simple processing at the ingress pipeline. Our ingress pipeline basically forwards the monitoring packets for a specific port, and all other traffic for other specific port. So, the first step is to edit our ingress pipeline at our p4code (mon.p4), with the correct port IDs of your environment (one from a monitoring server connected, and other random, but should be an active port).

```
nano p4codes/mon.p4
```

Then, edit the file "portConfig" with the appropriate ports (to activate the port connected to your server). This file is an bfshell script, so you can just modify the number of the ports in the commands.

```
nano portConfig
```

after that, you can run our script that will compile the P4 code, configure the ports, and run a bfshell to see if  is everything ok.

```
./run.sh
```

After the switch starts, goes to the monitoring server and run the scripts as explained in [hostScripts](hostScrits/Readme.md)


