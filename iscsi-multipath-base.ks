url --url http://TREE_IPBASE_TREE/

# System bootloader configuration
bootloader --location=mbr
text


firewall --disabled
firstboot --disable
keyboard us
lang en_US.UTF-8

# Network
network  --bootproto=dhcp --device=eth0 --noipv6 --activate
network  --hostname=HOSTNAME
network  --bootproto=static --device=eth1 --ip=IP1 --netmask=255.255.255.0 --nodns --nodefroute --gateway=192.168.123.0 --noipv6
network  --bootproto=static --device=eth2 --ip=IP2 --netmask=255.255.255.0 --nodns --nodefroute --gateway=192.168.124.0 --noipv6
network  --bootproto=static --device=eth3 --ip=IP3 --netmask=255.255.255.0 --nodns --nodefroute --gateway=192.168.125.0 --noipv6
network  --bootproto=static --device=eth4 --ip=IP4 --netmask=255.255.255.0 --nodns --nodefroute --gateway=192.168.126.0 --noipv6

reboot
#Root password
rootpw password
# SELinux configuration
selinux --permissive
# System timezone
timezone America/New_York
# Install OS instead of upgrade
install

zerombr
clearpart --all --initlabel

autopart

%packages --ignoremissing
@development
@development-libs
@development-tools
@server-platform-devel
kexec-tools
net-tools
ntpdate
sysstat
wget
dstat
vim
mlocate
yum-utils
iscsi-initiator-utils
device-mapper-multipath
#scsi-target-utils
targetcli
%end


%post --log=/dev/console
set -x

# Provide alternatives of network service setup.
systemctl disable NetworkManager.service > /dev/null 2>&1
systemctl disable NetworkManager-dispatcher.service > /dev/null 2>&1
systemctl disable NetworkManager-wait-online.service > /dev/null 2>&1
chkconfig network on > /dev/null 2>&1


# Set DEVTIMEOUT to wait for NIC stabilize.
for cfg in /etc/sysconfig/network-scripts/ifcfg-*; do
	[ "$(basename $cfg)" != "ifcfg-lo" ] && echo "DEVTIMEOUT=20" >> $cfg
done


# create setup and cleanup scripts
mkdir -p /root/bin/

cat << EOF > /root/bin/target-setup.sh
#!/bin/sh

targetcli << _EOL_
# make ramdisk for LUN
cd /backstores/ramdisk
create name=ram2g size=2G
# setup target00
/iscsi create iqn.0000-00.test.target00
cd /iscsi/iqn.0000-00.test.target00/tpg1
luns/ create /backstores/ramdisk/ram2g
set attribute authentication=0 demo_mode_write_protect=0 generate_node_acls=1 cache_dynamic_acls=1
# for CentOS7
portals/ create
cd /
ls
saveconfig
_EOL_
EOF
cat << EOF > /root/bin/target-cleanup.sh
#!/bin/sh

targetcli clearconfig true
EOF
cat << EOF > /root/bin/initiator-setup.sh
#!/bin/sh

TARGET_IP_LIST="192.168.123.2 192.168.124.2 192.168.125.2 192.168.126.2"

cat << _EOL_ > /etc/multipath.conf 
defaults {
	user_friendly_names yes
	find_multipaths yes
	path_grouping_policy multibus
}
blacklist {
	devnode "^vd[a-z]"
}
_EOL_

systemctl start multipathd

for i in \${TARGET_IP_LIST} ; do
	iscsiadm -m discovery -t st -p \${i}
done
iscsiadm -m node -l
udevadm settle

multipath
multipath -ll
udevadm settle

DEVNAME=\`lsblk -s |grep mpath | cut -d' ' -f1\`
ls -l /dev/disk/by-id/dm-name-\${DEVNAME}
mkfs.xfs  -f /dev/disk/by-id/dm-name-\${DEVNAME}
mkdir -p /mnt/iscsi
mount -o _netdev /dev/disk/by-id/dm-name-\${DEVNAME} /mnt/iscsi
EOF
cat << EOF > /root/bin/initiator-cleanup.sh
#!/bin/sh

umount /mnt/iscsi/
multipath -F
iscsiadm -m node -u
iscsiadm -m node -o delete
EOF
chmod +x /root/bin/*

%end
