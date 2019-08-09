#!/bin/bash
apt -y install libopus0 xorg xubuntu-desktop xfce4-terminal chromium-browser;
wget http://www.exabit.io/ubuntu/xrdp/xenial/xrdp_0.9.9-1ubuntu1_amd64.deb;
wget http://www.exabit.io/ubuntu/xrdp/xenial/xorgxrdp_0.2.9-1ubuntu1_amd64.deb;
dpkg -i ./xrdp_0.9.9-1ubuntu1_amd64.deb;
dpkg -i ./xorgxrdp_0.2.9-1ubuntu1_amd64.deb;
sed -i 's/^max_bpp=32$/max_bpp=15/' /etc/xrdp/xrdp.ini;
adduser xrdp ssl-cert;
systemctl restart xrdp;
