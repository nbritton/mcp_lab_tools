#!/bin/bash

# Name: create-virtual-machines, Version: 1
# Author: Nikolas Britton <nbritton@mirantis.com>
# Platform: Ubuntu 18.04 LTS
# Dependancies: virt-install libguestfs-tools qemu-utils libvirt-clients
# Prequisites: enable nested virtualization on the hypervisor host...
# echo "options kvm-intel nested=y" >> /etc/modprobe.d/kvm.conf && reboot;

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

pre_name_prefix="lab01-"
post_name_prefix=.mirantis.tech
disk_image="./ubuntu-16-04-x64-mcp2019.2.0.qcow2"
deployment_network=vbridge1
primary_network=vbridge2
deployment_subnet="10.11.0"
deployment_gateway="10.11.0.1"
deployment_netmask="255.255.255.0"
deployment_nameserver="8.8.8.8"
nic_interface_name=ens2
salt_master_address="10.11.0.15"

declare -Ax ip_addresses
ip_addresses=(
  [kvm01]="241"
  [kvm02]="242"
  [kvm03]="243"
  [cmp001]="101"
  [cmp002]="102"
  [cmp003]="103"
  [osd001]="201"
  [osd002]="202"
  [osd003]="203"
  [osd004]="204"
  [osd005]="205"
  [osd006]="206"
  [gtw01]="224"
  [gtw02]="225"
  [gtw03]="226"
  [upg01]="19"
)

declare -ax machines
machines=(
  "kvm"
  "cmp"
  "osd"
  "gtw"
  "upg"
)

declare -Ax kvm
kvm=(
  [node_count]=3
  [disk_size]=400
  [ram]=163840
  [cpus]=20
)

declare -Ax cmp
cmp=(
  [node_count]=3
  [disk_size]=30
  [ram]=163840
  [cpus]=20
)

declare -Ax osd
osd=(
  [node_count]=6
  [disk_size]=30
  [ram]=4096
  [cpus]=4
  [osd_count]=6
  [osd_size]=500
)

declare -Ax gtw
gtw=(
  [node_count]=3
  [disk_size]=30
  [ram]=2048
  [cpus]=4
)

declare -Ax upg
upg=(
  [node_count]=1
  [disk_size]=300
  [ram]=16384
  [cpus]=12
)

if ! [ $UID = "0" ]; then
  echo "You must be root to run this command."
  exit 1
fi

zfs_dataset_name=$(echo ${pre_name_prefix} | tr -d '-')
#zfs create tank/libvirt/images/${zfs_dataset_name};

if ! lsmod | grep -q nbd; then
  modprobe nbd max_part=8
fi

for i in "${machines[@]}"; do
  count=$i[node_count]
  for j in $(seq ${!count}); do
    ram=$i[ram]
    cpus=$i[cpus]
    disk_size=$i[disk_size]
    case $i in
    cmp)
      short_name=${i}00${j}
      long_name=${pre_name_prefix}${short_name}${post_name_prefix}
      ;;
    osd)
      short_name=${i}00${j}
      long_name=${pre_name_prefix}${short_name}${post_name_prefix}
      ;;
    *)
      short_name=${i}0${j}
      long_name=${pre_name_prefix}${short_name}${post_name_prefix}
      ;;
    esac
    cp -p ${disk_image} /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}.qcow2
    chown libvirt-qemu:kvm /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}.qcow2
    qemu-img resize /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}.qcow2 ${!disk_size}G
    guestmount -a /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}.qcow2 -m /dev/sda1 /mnt
    deployment_address=${deployment_subnet}.${ip_addresses[$short_name]}
    cat <<EOF >/mnt/etc/network/interfaces
auto lo
iface lo inet loopback

auto ${nic_interface_name}
iface ${nic_interface_name} inet static
    address ${deployment_address}
    netmask ${deployment_netmask}
    gateway ${deployment_gateway}
    dns-nameservers ${deployment_nameserver}
EOF
    echo "network: {config: disabled}" >/mnt/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    rm /mnt/etc/network/interfaces.d/*
    echo "master: ${salt_master_address}" >>/mnt/etc/salt/minion.d/minion.conf
    echo "id: ${short_name}${post_name_prefix}" >>/mnt/etc/salt/minion.d/minion.conf
    guestunmount /mnt
    virt-install \
      --name ${long_name} \
      --memory ${!ram} \
      --vcpus ${!cpus} \
      --cpu host \
      --controller usb,model=none \
      --graphics none \
      --sound none \
      --network bridge=${deployment_network} \
      --network bridge=${primary_network} \
      --network bridge=${primary_network} \
      --disk /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}.qcow2 \
      --noautoconsole \
      --boot hd \
      --os-variant ubuntu16.04 \
      --autostart
    case $i in
    osd)
      osd_count=$i[osd_count]
      osd_size=$i[osd_size]
      for k in $(seq ${!osd_count}); do
        qemu-img create -f qcow2 /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}-${k}.qcow2 ${!osd_size}G
        chown libvirt-qemu:kvm /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}-${k}.qcow2
        virsh attach-disk \
          ${long_name} \
          --source /var/lib/libvirt/images/${zfs_dataset_name}/${long_name}-${k}.qcow2 \
          --persistent \
          --targetbus virtio \
          --subdriver qcow2 \
          --target vd$(echo ${k} | tr 123456789 bcdefghij)
      done
      ;;
    *)
      ;;
    esac
  done
done
