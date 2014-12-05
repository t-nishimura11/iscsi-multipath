#!/bin/sh

BASE_KS="iscsi-multipath-base.ks"
TREE_HOST="mirrors.mit.edu"
BASE_TREE="/centos/7/os/x86_64"

IMG_DIR="/home/img"
mkdir -p ${IMG_DIR}

for i in initiator target ; do
	sed -e "s/HOSTNAME/${i}/g" ${BASE_KS}> ${i}.ks
	sed -i "s:TREE_HOST:${TREE_HOST}:g" ${i}.ks
	sed -i "s:BASE_TREE:${BASE_TREE}:g" ${i}.ks
	if [ "${i}" == "initiator" ]; then
		sed -i "s/IP1/192.168.123.1/g" ${i}.ks
		sed -i "s/IP2/192.168.124.1/g" ${i}.ks
		sed -i "s/IP3/192.168.125.1/g" ${i}.ks
		sed -i "s/IP4/192.168.126.1/g" ${i}.ks
	else
		sed -i "s/IP1/192.168.123.2/g" ${i}.ks
		sed -i "s/IP2/192.168.124.2/g" ${i}.ks
		sed -i "s/IP3/192.168.125.2/g" ${i}.ks
		sed -i "s/IP4/192.168.126.2/g" ${i}.ks
	fi

	cat << _EOL_ > create-${i}.sh
#!/bin/sh

virt-install \\
--name ${i} \\
--ram 6144 --vcpus=6 \\
--extra-args="console=tty0 console=ttyS0,115200n8 ks=file:/${i}.ks" \\
--location="http://${TREE_HOST}${BASE_TREE}" \\
--disk path=${IMG_DIR}/${i}.img,size=30 \\
--nographics \\
--accelerate \\
--hvm \\
--initrd-inject ${i}.ks \\
--network network=default \\
_EOL_
	chmod +x create-${i}.sh

	cat << _EOL_ > cleanup-${i}.sh
#!/bin/sh

virsh destroy ${i}
virsh undefine ${i}
rm -f /home/img/${i}.img
_EOL_
	chmod +x cleanup-${i}.sh
done

cat << _EOL_ > cleanup-network.sh
#!/bin/sh


_EOL_
chmod +x cleanup-network.sh

NET_NUM="3"
for i in `seq -w 0 ${NET_NUM}`; do
	cat << _EOL_ > /tmp/local${i}.xml
<network>
	<name>local${i}</name>
	<bridge name='local${i}' stp='on' delay='0' />
</network>
_EOL_
	virsh net-create /tmp/local${i}.xml
	rm -f /tmp/local${i}.xml
	echo "--network network=local${i} \\" >> create-initiator.sh
	echo "--network network=local${i} \\" >> create-target.sh
	echo "virsh net-destroy local${i}" >> cleanup-network.sh
	
done

cat << _EOL_ > remove-tmp_files.sh
#!/bin/sh

rm -rf ./cleanup-*.sh
rm -rf ./create-*.sh
rm -rf initiator.ks target.ks
_EOL_
chmod +x remove-tmp_files.sh
