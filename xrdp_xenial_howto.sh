### xrdp 0.9.9 and xorgxrdp 0.2.9 for xenial, Mirantis MCP 2019.2.0. ###

# Build xrdp 0.9.9
apt -y install build-essential devscripts fakeroot autoconf automake debhelper libfuse-dev libjpeg-dev libopus-dev libpam0g-dev libssl-dev libtool libx11-dev libxfixes-dev libxrandr-dev nasm openssl pkg-config systemd;

mkdir ~/build/xrdp;
cd ~/build/xrdp;
wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xrdp/xrdp_0.9.9-1.dsc;
wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xrdp/xrdp_0.9.9.orig.tar.gz;
wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xrdp/xrdp_0.9.9-1.debian.tar.xz;
dpkg-source -x xrdp_0.9.9-1.dsc;

cd ~/build/xrdp/xrdp-0.9.9;
debchange;
debuild -b -uc -us;
tar -Jcf ~/xrdp-0.9.9-xenial.tar.xz ../xrdp;

# Build xorgxrdp 0.2.9
# xrdp is a build dependancy for xorgxrdp
apt -y install autoconf automake debhelper nasm pkg-config x11-utils xrdp xserver-xorg-core xserver-xorg-dev;

mkdir ~/build/xorgxrdp;
cd ~/build/xorgxrdp;
wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xorgxrdp/xorgxrdp_0.2.9-1.dsc
wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xorgxrdp/xorgxrdp_0.2.9.orig.tar.gz
wget http://archive.ubuntu.com/ubuntu/pool/universe/x/xorgxrdp/xorgxrdp_0.2.9-1.debian.tar.xz
dpkg-source -x xorgxrdp_0.2.9-1.dsc;

cd ~/build/xorgxrdp/xorgxrdp-0.2.9;
debchange;
debuild -b -uc -us;
tar -Jcf ~/xorgxrdp-0.2.9-xenial.tar.xz ../xorgxrdp;


# Install
apt -y install libopus0 xorg xfce4 chromium-browser xfce4-terminal;

dpkg -i xrdp_0.9.9-1ubuntu1_amd64.deb;
dpkg -i xorgxrdp_0.2.9-1ubuntu1_amd64.deb;
adduser xrdp ssl-cert;
systemctl restart xrdp;

echo "xfce4-session" > /root/.xession;
echo "xfce4-session" > /home/nbritton/.xession;
echo "xfce4-session" >> /etc/xrdp/startwm.sh;
sed -i '/\/etc\/X11\/Xsession/ s/^/#/' /etc/xrdp/startwm.sh;
systemctl restart xrdp;
