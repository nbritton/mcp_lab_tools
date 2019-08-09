#!/bin/bash

### Install packages;
apt update;
apt upgrade -y;
apt install -y qemu-kvm libvirt-bin virtinst bridge-utils cpu-checker virt-manager xrdp xfce4 firefox xfce4-terminal nmap iotop sysstat linux-tools-generic linux-tools-common libguestfs-tools smartmontools zfsutils-linux;

### Disable IPv6 due to bugs... ####
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"/' /etc/default/grub;
update-grub;

### Setup Network Dummy Interfaces ###
printf "[NetDev]\nName=dummy1\nKind=dummy\n" > /etc/systemd/network/dummy1.netdev;
printf "[NetDev]\nName=dummy2\nKind=dummy\n" > /etc/systemd/network/dummy2.netdev;
printf "[NetDev]\nName=dummy3\nKind=dummy\n" > /etc/systemd/network/dummy3.netdev;
printf "[NetDev]\nName=dummy4\nKind=dummy\n" > /etc/systemd/network/dummy4.netdev;
printf "[NetDev]\nName=dummy5\nKind=dummy\n" > /etc/systemd/network/dummy5.netdev;
printf "[NetDev]\nName=dummy6\nKind=dummy\n" > /etc/systemd/network/dummy6.netdev;
systemctl restart systemd-networkd.service;

### Netplan configuration ###
cat << 'EOF' > /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: networkd

  ethernets:
    eno3: {}
    eno4: {}
    dummy1: {}
    dummy2: {}

  vlans:
    vbridge2-vlan10:
      id: 10
      link: vbridge2
      addresses: [10.11.1.2/24]
    vbridge2-vlan20:
      id: 20
      link: vbridge2
      addresses: [10.11.2.2/24]

  bonds:
    bond1:
      interfaces: [eno3, eno4]

  bridges:
    lab:
      interfaces: [bond1]
      addresses: [10.10.2.2/16]
      gateway4: 10.10.0.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
    vbridge1:
      interfaces: [dummy1]
      addresses: [10.11.0.2/24]
    vbridge2:
      interfaces: [dummy2]
EOF
netplan apply;

### Enable nested virtualization ###
echo "options kvm-intel nested=y" >> /etc/modprobe.d/kvm.conf;

### Enable XRDP server ###
ufw allow 3389/tcp;
echo "xfce4-session" > /root/.xession;
echo "xfce4-session" > /home/nbritton/.xession;
echo "xfce4-session" >> /etc/xrdp/startwm.sh;
sed -i '/\/etc\/X11\/Xsession/ s/^/#/' /etc/xrdp/startwm.sh;
systemctl restart xrdp;

#reboot;
