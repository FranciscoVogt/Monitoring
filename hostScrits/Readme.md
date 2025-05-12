# Hosts Scripts to Generate Traffic and Monitor the Networ Status

Below are the description of the scripts in this folder, and how to use it.

## Scripts:

### createRandomFlows.py
> **Description:** Generate a number of UDP flows with random mac addresses and a predefined and individual throughput (Mbps). After generated, start using TCPReplay, and show the flowID (CRC 32 of src and dst mac, used to indentify the flow and collect the metrics further).

> **Parameters:** `-nFlows`, where receive the number of flows to be generated, followed by the throughput of each flow.

> **Example:** `python3 createRandomFlows.py -nFlows 3 10 20 30` will generate 3 flows with the first flow at 10 Mbps, second flow at 20 Mbps and third flow at 30 Mbps.

### instructions.txt
> **Description:** File containing the definitions of which flows and ports will be monitored. Each line in this file will create a new monitoring flow according to the definitions.

> **Structure:** `flow=x, port=y, period=z, dstPort=q`, where flow and port are the monitoring targets (flow uses an ID of 12 bits CRC32 of src and dst mac, and the port is the port ID on tofino), period is the frequency that monitoring packets are sent, and the dstPort is the port ID of the monitoring server, therefore the port that the monitoring packets are forwarded at tofino.

> **Example:** `flow=2551, port=132, period=0.01, dstPort=134`, will monitor the flow with ID 2551 (12 bits CRC32 of src/dst mac), the port ID 132, sending packets every 0.1 seconds, and these packets are forwarded to tofino port 134.

### showInfo.py
> **Description:** Show the information about the monitored flows and ports. This code has two threads, one actively receiving the monitored packets and computing statistics, and other showing these statistics in the screen every 1 second.

> **Parameters:** `--iface`, that receive the server interface that the listener will wait for the monitoring packets.

> **Example:** `sudo python3 showInfo.py --iface enp6s0f0'

### finalSender.py
> **Description:** Generate the monitoring packets according to the instructions.txt configurations.

> **Parameters:** `-i` interface to send the packets, `-file` file of configurations (instructions.txt).

> **Example:** `sudo python3 finalSender.py -i enp6s0f0 -file instructions.txt`

### run_monitoring.sh
> **Description:** Script to run all the above scripts (excluding the createRandomFlows.py), and start the monitoring using just one terminal.

> **Parameters:** `-rxIntf` interface that will receive the moitoring packets, `-txIntf` interface where send the monitoring packets, `-file` instructions file to create the monitoring flows.

> **Example:** sudo ./run_monitoring.sh -rxIntf enp6s0f0 -txIntf enp6s0f1 -file instructions.txt

