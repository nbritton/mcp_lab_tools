#!/bin/bash

# If you don't have DHCP running on the virtual deployment network you can use this to bootstrap
# the control plane nodes. This is to be run from within the virtual kvm node for the purpose of
# standing up the virtual control plane that is nested inside the kvm nodes, i.g. ctl, dbs, msg.
# lab hypervisor node --> virtualized kvm hypervisor node --> virtual control plane nodes.

# Set ip to any valid starting value and it will iterate up one value for each node.
# For each kvm node you would need to choose a new starting ip so you don't have a
# colision with the virtual machines running on the other kvm nodes. Then once
# all of the virtual machines for the virtual control plane are up you can provision
# them they're final ip address that is set in the reclass model via the standard:
# salt '*' state.sls linux.network.interface.

# Besure when generating your model with the model designer tool that it select the
# static deploy network addresses, otherwise no deploy addresses will be set in the model.

ip=51;
subnet="10.11.12";
netmask="255.255.255.0";

for i in $(virsh list --all --name | grep -v cfg01); do
  virsh destroy ${i} && sleep;
	guestmount -a /var/lib/libvirt/images/${i}/system.qcow2 -m /dev/vg0/root /mnt;
	echo "root:password" | chpasswd -R /mnt;
	rm -rf /mnt/etc/network/interfaces.d/50-cloud-init.cfg;
	echo -e "auto lo\niface lo inet loopback\n" > /mnt/etc/network/interfaces;
	echo -e "auto ens2\niface ens2 inet static\n\taddress ${subnet}.${ip}\n\tnetmask ${netmask}" >> /mnt/etc/network/interfaces;
	guestunmount /mnt;	
	ip=$(($ip+1));
	virsh start ${i};
done