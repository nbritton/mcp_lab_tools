# mcp_lab_tools
Mirantis MCP Virtual Lab Provisioning Tools

Use lab_setup.sh to setup a Ubuntu Server 18.04 LTS machine for use as a virtual lab. The network configuration provided in the script for illustrative purposes, you will more then likely have to reconfigure the settings to the networks you want to use. The dummy networks are a key enabler here, they function as a virtual network interface and you can use them like you would any network interface... it's just that they're not connected to anything in the outside world. To enable connectivity between the Internet and the virtual networks you need a virtual routing gateway. I personally use ClearOS because it has a turnkey OpenVPN implementation (which allows you to VPN into the virtual networks from your MacBook via Tunnelblick). Alternatively you could probably also use iptables to forward packets to the right networks. Bonds, bridges, and VLANs are supported on top of the dummy virtual interfaces... which should allow you to replicate practically any configuration found in production.

Also, the nested virtual machines running on the kvm nodes will require you to have a DHCP server running on the virtual deployment network, this is also why I use ClearOS rather then iptables.

You can have more then one virtual lab, simply change the prefix variable before running the create-virtual-machines script. In a simple single physical machine layout you could simply do lab01-, lab02-, lab03-. Then when you run virsh list --all you will see all the machines, such as lab01-kvm01.mylab.local, lab02-kvm01.myotherlab.local. If you have multiple phsyical machines then I would recommend prefixing with something like aa<subnet>- for hypervisor 1, ab<subnet>- for hypervisor 2, and ac<subnet> for hypervisor 3, etc... this would let you 52 physical hypervisor machines and unlimited subnets without having any naming collisions. Each discrete virtual lab should have its own virtual router, i.g. aa<subnet>-vrouter, ab<subnet>-vrouter. The setup of ClearOS can be automated for dynamic provisioning, I just haven't had time to play around with that.

If you are running a full HA production scale MCP cluster in a virtual lab then you will need about a minimum of 400GB of system memory. If you don't have this much memory a workable alternative is to setup an SSD as a swap partition, preferably you'd have something like an Intel Optane 900p laying around, but a regular PCI NVMe SSD card should work well too.

I've noticed during use that sometimes the virtual machines nested on the virtual kvm nodes can stall, for instance when running salt commands the process doesn't actually start and/or return. My educated guess is it's a problem with the process scheduler. It only happens under very heavy load, for instance on my Dell R920 with quad Intel Xeon E7-8895 v2 processors (60 physical cores, 120 hyper-threaded) this only happens after trying to run three full scale labs concurrently, which is equivalent to about 140 virtual machines. It could also be due to QPI bottlenecks because I was not doing any form of cpu pinning. I saw noticeable stability improvements by setting the processor's frequency governor to a fix frequency, dynamic turbo-boosting should be disabled. I also believe I noticed an improvement by using the lowlatency kernel, I recommend whatever the current HWE lowlatency kernel is:

sudo apt-get install --install-recommends linux-lowlatency-hwe-18.04;

It's best to setup the lab on ZFS, or another filesystem that supports atomic CoW snapshoting. This is fundamentally required because it lets you roll back the whole cluster with a a few simple commands. You would create each discrete lab in it's own seperate ZFS dataset, i.g.

zpool create data raidz /dev/disk1 /dev/disk2 /dev/disk3;
zfs create data/images;
zfs set mountpoint=/var/lib/libvirt/images data/images;
zfs create data/images/lab01;
zfs snapshot data/images/lab01@my-snapshot-name;
zfs rollback data/images/lab01@my-snapshot-name;

You can also setup the virtual networks across machines, this is useful if you don't have enough resources on a single lab hypervisor instance to run the whole MCP HA stack. For instance if you have three machines with 128GB of memory on them each then this should be enough to memory to scale a production scale MCP cluster across them:

lab hypervisor 1: kvm1, osd1/2, gtw1, and cmp1. 
lab hypervisor 2: kvm2, osd3/4, gtw2, and cmp2. 
lab hypervisor 3: kvm3, osd5/6, gtw3, and cmp3.

The virtual dummy networks on the three lab hypervisors are all on separate layer 2 domains, which is to say that they're not connected at all except for layer 3 access through the vrouter gateway. The way you can connect the virtual dummy networks together on the three lab hypervisors into a single logical domain is to create a layer 2 mesh overlay network on the lab hypervisors. This can be done using Open vSwitch with Stateless Transport Tunneling ("STT"), I maintain a DPDK enabled OVS package repository for Ubuntu 18.04 here: http://www.exabit.io/ubuntu
