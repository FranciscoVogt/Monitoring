from scapy.all import *
from scapy.fields import *
from collections import defaultdict
import threading
import argparse
import time
import os

# ====== Header monitor_inst_h ======
class MonitorInst(Packet):
    name = "MonitorInst"
    fields_desc = [
        IntField("index_flow", 0),
        IntField("index_port", 0),
        BitField("port", 0, 9),
        BitField("padding", 0, 7)
    ]

# ====== Header monitor_h ======
class Monitor(Packet):
    name = "Monitor"
    fields_desc = [
        LongField("bytes_flow", 0),
        LongField("bytes_port", 0),
        BitField("timestamp", 0, 48),  # 6 bytes
        BitField("port", 0, 9),
        BitField("padding", 0, 7),
        ShortField("pktLen", 0),

        IntField("qID_port", 0),
        IntField("qDepth_port", 0),
        IntField("qTime_port", 0),

        IntField("qID_flow", 0),
        IntField("qDepth_flow", 0),
        IntField("qTime_flow", 0)
    ]

# ====== Ligação dos headers ======
bind_layers(Ether, MonitorInst, type=0x1234)
bind_layers(MonitorInst, Monitor)

# ====== Dados anteriores e Throughputs ======
prev_data = {
    "flow": defaultdict(lambda: {"bytes": 0, "timestamp": 0}),
    "port": defaultdict(lambda: {"bytes": 0, "timestamp": 0})
}

throughputs = {
    "flow": defaultdict(float),
    "port": defaultdict(float)
}

last_seen = {
    "flow": defaultdict(lambda: 0),
    "port": defaultdict(lambda: 0)
}

lock = threading.Lock()

def process_packet(pkt):
    if Monitor in pkt:
        inst = pkt[MonitorInst]
        mon = pkt[Monitor]

        flow_id = inst.index_flow
        port_id = inst.index_port
        ts = mon.timestamp  # em nanossegundos (48 bits)
        bf = mon.bytes_flow
        bp = mon.bytes_port
        now = time.time()

        with lock:
            # Processa dados do fluxo (se válido)
            if flow_id != 0:
                prev = prev_data["flow"][flow_id]
                if prev["timestamp"] != 0 and ts > prev["timestamp"]:
                    delta_bytes = bf - prev["bytes"]
                    delta_time = (ts - prev["timestamp"]) / 1e9
                    if delta_time > 0:
                        mbps = (delta_bytes * 8) / (delta_time * 1e6)
                        throughputs["flow"][flow_id] = mbps
                prev_data["flow"][flow_id] = {"bytes": bf, "timestamp": ts}
                last_seen["flow"][flow_id] = now

            # Processa dados da porta (se válido)
            if port_id != 0:
                prev = prev_data["port"][port_id]
                if prev["timestamp"] != 0 and ts > prev["timestamp"]:
                    delta_bytes = bp - prev["bytes"]
                    delta_time = (ts - prev["timestamp"]) / 1e9
                    if delta_time > 0:
                        mbps = (delta_bytes * 8) / (delta_time * 1e6)
                        throughputs["port"][port_id] = mbps
                prev_data["port"][port_id] = {"bytes": bp, "timestamp": ts}
                last_seen["port"][port_id] = now

def display_loop():
    while True:
        time.sleep(1)
        os.system("clear")
        now = time.time()
        with lock:
            print("\n=== [Throughput Report] ===")
            print("---- Flows ----")
            for fid in sorted(list(throughputs["flow"].keys())):
                if now - last_seen["flow"][fid] <= 5:
                    if now - last_seen["flow"][fid] <= 1:
                        print(f"Flow {fid}: {throughputs['flow'][fid]:.2f} Mbps")
                    else:
                        print(f"Flow {fid}: 0.00 Mbps")

            print("---- Ports ----")
            for pid in sorted(list(throughputs["port"].keys())):
                if now - last_seen["port"][pid] <= 5:
                    if now - last_seen["port"][pid] <= 1:
                        print(f"Port {pid}: {throughputs['port'][pid]:.2f} Mbps")
                    else:
                        print(f"Port {pid}: 0.00 Mbps")

def main():
    parser = argparse.ArgumentParser(description="Monitoring packet receiver")
    parser.add_argument("--iface", default="enp6s0f0", help="Interface to listen on")
    args = parser.parse_args()

    t = threading.Thread(target=display_loop, daemon=True)
    t.start()

    print(f"Listening on interface {args.iface} for ethertype 0x1234 packets")
    sniff(iface=args.iface, filter="ether proto 0x1234", prn=process_packet)

if __name__ == "__main__":
    main()

