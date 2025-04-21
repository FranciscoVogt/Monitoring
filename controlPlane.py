p4 = bfrt.mon.pipe

fwd_table = p4.SwitchIngress.fwd


fwd_table.add_with_send(ctrl=2, port=160)

bfrt.complete_operations()
