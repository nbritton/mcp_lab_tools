#!/bin/bash

# This script illustrates and example of a lab hypervisor configured with a layer 2 mesh overlay
# network for establishing a virtual network that spans across multiple lab hypervisors.
# Ubuntu Server 18.04.2 + OVS 2.11 + DPDK 18.11

apt update;
apt-get -y install --install-recommends linux-lowlatency-hwe-18.04;
apt -y upgrade;
echo "deb http://www.exabit.io/ubuntu bionic main" > /etc/apt/sources.list.d/exabit.io.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys A40225E9C43E5E4B
apt update;
apt -y install openvswitch-dpdk-modules-4.18.0-17-generic;

# Open vSwitch Settings
ovs-vsctl set Bridge overlay0 stp_enable=true;
for i in $(ovs-vsctl list-ports overlay0); do ovs-vsctl set Interface $i mtu_request=9000; done;
ovs-vsctl set int overlay0 mtu_request=9000;

cat << 'EOF' > /etc/libvirt/kvm-overlay0.xml
<network>
    <name>kvm-overlay0</name>
    <forward mode='bridge'/>
    <bridge name='overlay0'/>
    <virtualport type='openvswitch'/>
</network>
EOF

virsh net-define /etc/libvirt/kvm-overlay0.xml;
virsh net-start kvm-overlay0;
virsh net-autostart kvm-overlay0;

virt-install --name test01 --memory 16384 --vcpus 10 --cpu host --controller usb,model=none --graphics none --sound none --network=bridge:overlay0,model=virtio,virtualport_type=openvswitch --disk /var/lib/libvirt/images/test01/system.qcow2 --noautoconsole --boot hd --os-variant ubuntu16.04 --autostart;
