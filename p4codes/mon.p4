#include <tna.p4>

#include "byteCount.p4"


typedef bit<48> mac_addr_t;
typedef bit<12> vlan_id_t;
typedef bit<16> ether_type_t;
typedef bit<32> ipv4_addr_t;

const ether_type_t ETHERTYPE_IPV4 = 16w0x0800;
const ether_type_t ETHERTYPE_VLAN = 16w0x8100;

const ether_type_t ETHERTYPE_MONITOR = 0x1234;

header ethernet_h {
	mac_addr_t dst_addr;
	mac_addr_t src_addr;
	bit<16> ether_type;
}

header vlan_tag_h {
	bit<3> pcp;
	bit<1> cfi;
	vlan_id_t vid;
	bit<16> ether_type;
}

header ipv4_h {
	bit<4> version;
	bit<4> ihl;
	bit<8> diffserv;
	bit<16> total_len;
	bit<16> identification;
	bit<16> flags;
	bit<8> ttl;
	bit<8> protocol;
	bit<16> hdr_checksum;
	ipv4_addr_t src_addr;
	ipv4_addr_t dst_addr;
}

header monitor_h {
	bit<64> bytes;
	bit<48> timestamp;
	bit<9> port;
}

struct headers {
	pktgen_timer_header_t timer;
	ethernet_h	ethernet;
	monitor_h	monitor;
	vlan_tag_h	vlan_tag;
	ipv4_h		ipv4;
}

struct my_ingress_metadata_t {
	bit<8> ctrl;
}

struct my_egress_metadata_t {

}


parser SwitchIngressParser(
	packet_in packet, 
	out headers hdr, 
	out my_ingress_metadata_t ig_md,
	out ingress_intrinsic_metadata_t ig_intr_md) {

	/*state start {
		packet.extract(ig_intr_md);
		packet.advance(PORT_METADATA_SIZE);
		
		transition parse_ethernet;
	}*/


	state start {
		packet.extract(ig_intr_md);
		packet.advance(PORT_METADATA_SIZE);
		
		pktgen_timer_header_t pktgen_pd_hdr = packet.lookahead<pktgen_timer_header_t>();
		transition select(pktgen_pd_hdr.app_id) {
			1 : parse_pktgen_timer;
			default : reject;
		}	
	}




	state parse_pktgen_timer {
		//packet.extract(hdr.timer);
		ig_md.ctrl = 2;
		transition parse_ethernet;
	}

	state parse_ethernet {
		packet.extract(hdr.ethernet);
		//ig_md.ctrl = 2;
		transition select(hdr.ethernet.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			ETHERTYPE_VLAN:  parse_vlan;
			default: accept;
		}
	}

	state parse_vlan {
		packet.extract(hdr.vlan_tag);
		transition select(hdr.vlan_tag.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			default: accept;
		}
	}
	
	state parse_ipv4 {
		packet.extract(hdr.ipv4);
		transition accept;
	}
}


control SwitchIngress(
	inout headers hdr, 
	inout my_ingress_metadata_t ig_md,
	in ingress_intrinsic_metadata_t ig_intr_md,
	in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
	inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
	inout ingress_intrinsic_metadata_for_tm_t ig_intr_tm_md) {
		
	action drop() {
		ig_intr_dprsr_md.drop_ctl = 0x1;
	}
	
	action send(PortId_t port) {
		ig_intr_tm_md.ucast_egress_port = port;
	}
  
	table fwd {
		key = {
			ig_md.ctrl	:	exact;
		}
		actions = {
			send;
			drop;
		}
		const default_action = drop();
		size = 1024;
	}
		
	apply {
		
		//fwd.apply();

		if(ig_md.ctrl==2){
			hdr.monitor.isValid();
			hdr.ethernet.ethertype = ETHERTYPE_MONITOR;
			ig_intr_tm_md.ucast_egress_port = 160;
		}
		
		//need to adjust the parser still
		/*if(ig_intr_md.ingress_port==196 || ig_intr_md.ingress_port==68){
			hdr.monitor.isValid();
			hdr.ethernet.ethertype = ETHERTYPE_MONITOR;
		}*/
		
	}
		
}


control SwitchIngressDeparser(
	packet_out pkt,
	inout headers hdr,
	in my_ingress_metadata_t ig_md,
	in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {

	apply {
		pkt.emit(hdr);
	}
}


parser SwitchEgressParser(
	packet_in packet,
	out headers hdr,
	out my_egress_metadata_t eg_md,
	out egress_intrinsic_metadata_t eg_intr_md) {
	
	state start {
		packet.extract(eg_intr_md);
		transition parse_ethernet;
	}
	
	state parse_ethernet {
		packet.extract(hdr.ethernet);
		transition select(hdr.ethernet.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			ETHERTYPE_VLAN:  parse_vlan;
			ETHERTYPE_MONITOR: parse_monitor;
			default: accept;
		}
	}

	state parse_monitor {
		packet.extract(hdr.monitor);
		transition accept;
	
	}

	state parse_vlan {
		packet.extract(hdr.vlan_tag);
		transition select(hdr.vlan_tag.ether_type) {
			ETHERTYPE_IPV4:  parse_ipv4;
			default: accept;
		}
	}
	
	state parse_ipv4 {
		packet.extract(hdr.ipv4);
		transition accept;
	}
}


control SwitchEgress(
	inout headers hdr,
	inout my_egress_metadata_t eg_md,
	in egress_intrinsic_metadata_t eg_intr_md,
	in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
	inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
	inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {
	

	Add_64_64(4096) byte_count;


	
	apply {
	
	
		if(hdr.monitor.isValid()){
			hdr.monitor.timestamp = eg_intr_from_prsr.global_tstamp;
			hdr.monitor.port = eg_intr_md.egress_port;
			
			byte_count.apply(hdr.monitor.bytes, eg_intr_md.pkt_length, (bit<32>)eg_intr_md.egress_port);
			
		}
	}
}

control SwitchEgressDeparser(
	packet_out pkt,
	inout headers hdr,
	in my_egress_metadata_t eg_md,
	in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
		
	apply {
		pkt.emit(hdr);
	}
}

Pipeline(SwitchIngressParser(),
		SwitchIngress(),
		SwitchIngressDeparser(),
		SwitchEgressParser(),
		SwitchEgress(),
		SwitchEgressDeparser()) pipe;

Switch(pipe) main;
