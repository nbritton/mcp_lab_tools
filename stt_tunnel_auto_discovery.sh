#!/bin/bash

# Name: stt-tunnel-auto-discovery, Version: 1
# Author: Nikolas Britton <nbritton@mirantis.com>
# Platform: Ubuntu 18.04 LTS
# Dependancies: ovs-vsctl nmap

# Description: Open vSwitch Stateless Transport Tunneling Auto Discovery. This bash script will automatically
# discover and establish STT tunnel connections to other Open vSwitch nodes that are on the same subnet.
# This allows you to setup and maintain a virtual layer 2 mesh overlay. It uses Spanning Tree Protocal
# ("STP") to prevent bridge loops, so it's only a pseudo mesh network, for OVS to do real mesh networking
# the OVS team would need to implement Shortest Path Bridging ("SPB") or TRansparent Interconnection of Lots
# of Links ("TRILL")... which as far as I can tell there is not a working open source implimentation of
# SPB and/or TRILL for Linux yet.

# Copyright 2019 Nikolas Britton
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
# associated documentation files (the "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to
# the following conditions:

# The above copyright notice and this permission notice shall be included in all copies or substantial
# portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
# LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Name of network interface to check.
network_interface="ens3";

# Name of bridge to attach STT tunnels to.
my_bridge="overlay0"

# Prefix of STT tunnel device. i.g. for stt0, stt1, stt2, ... sttn, use stt
my_tunnel=stt

# IP and CIDR of network interface.
my_network="$(ip -4 addr show ${network_interface} | awk '/inet/ {print $2}')";

if ! [ $UID = "0" ]; then
    echo "You must be root to run this command.";
    exit 1;
fi

test -x $(which nmap) || {
	echo "You must have nmap installed to run this command.";
	exit 1;
}

# This script is keyed to a fingerprint, it will only establish
# connections with other nodes that have the same fingerprint.
# A fingerprint can be any md5 hash.

# Get the fingerprint of this node.
get_fingerprint () {
	fingerprint=$(awk '/VersionAddendum/ {print $2}' /etc/ssh/sshd_config);

	if ! [[ $fingerprint =~ [0-9a-f]{32}? ]]; then
		echo "A fingerprint does not appear to be set for this node, is it a valid md5 hash?";
		echo "The current fingerprint is: ${fingerprint}";
		echo "To generate an new random fingerprint run: $(basename "${0}") --gen";
		echo "To set a new fingerprint run: $(basename "${0}") --set <md5 hash>";
		exit 1;
	fi
}

check_fingerprint () {
	echo "check_fingerprint 1: $1 $2";
	if ! [[ $1 =~ ^[0-9a-f]{32}?$ ]]; then
		echo "check_fingerprint 2: $1 $2";
		echo "The fingerprint provided does not appear to be a valid md5 hash.";
		exit 1;
	fi
	return 0;
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    --get)
	get_fingerprint && echo $fingerprint;
	exit 0;
    ;;
    --set) # Set the finngerprint of this node.
		echo "set fingerprint $2";
	check_fingerprint ${2} && {
		sed -i "s/.*VersionAddendum.*/VersionAddendum ${2}/" /etc/ssh/sshd_config && {
			systemctl restart sshd;
			exit;
		};
	}
	;;
    --gen) # Generate a random fingerprint.
	md5sum <(dd if=/dev/urandom bs=8K count=1 2>/dev/null) | awk '{print $1}';
	exit 0;
	;;
    --add) # Add nodes to Open vSwtich
	get_fingerprint;

	# This gets a list of the nodes that having a matching fingerprint.
	mapfile -t nodes_with_fingerprint < <(nmap -p 22 --open -n -oG - -sV ${my_network} | awk "/${fingerprint}/ {print \$2}");

	# This will remove itself from the node list and sorts the results.
	mapfile -t stt_tunnel_nodes < <(printf '%s\n' "${nodes_with_fingerprint[@]}" | fgrep -v ${my_network%/*} | sort -n -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4)

	for i in $(seq ${!stt_tunnel_nodes[@]}); do
		echo "ovs-vsctl add-port ${my_bridge} ${my_tunnel}${i} -- set interface ${my_tunnel}${i} type=stt options:local_ip=${my_network%/*} options:remote_ip=${stt_tunnel_nodes[${i}]}";
	done
	exit 0;
	;;
	--del) # Delete nodes from Open vSwitch
	echo "not defined yet.";
	;;
    *) # Unkown option.
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

set -- "${POSITIONAL[@]}" # restore positional parameters
