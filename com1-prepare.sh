#!/bin/bash -ex
#

source config.cfg

# Cau hinh cho file /etc/hosts
# COM1_IP_MGNT=10.10.10.73
# COM1_IP_DATA=10.10.20.73
# COM2_IP_MGNT=10.10.10.74
# COM2_IP_DATA=10.10.20.74
# CON_IP_EX=192.168.1.71
# CON_IP_MGNT=10.10.10.71
# ADMIN_PASS=a
# RABBIT_PASS=a
#
iphost=/etc/hosts
test -f $iphost.orig || cp $iphost $iphost.orig
rm $iphost
touch $iphost
cat << EOF >> $iphost
127.0.0.1       localhost
$CON_MGNT_IP    controller
$COM1_MGNT_IP      compute1
127.0.0.1        compute1
$COM2_MGNT_IP      compute2
$NET_MGNT_IP     network
EOF

apt-get update -y
apt-get upgrade -y
apt-get dist-upgrade -y

# Cai dat repos va update
apt-get install ubuntu-cloud-keyring
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
apt-get update && apt-get -y upgrade && apt-get -y dist-upgrade 


# apt-get update -y
# apt-get upgrade -y
# apt-get dist-upgrade -y

########
echo "############ Cai dat NTP ############"
########
#Cai dat NTP va cau hinh can thiet 
apt-get install ntp -y
apt-get install python-mysqldb -y

# Cai cac goi can thiet cho compute 
apt-get install nova-compute sysfsutils -y

########
echo "############ Cau hinh NTP ############"
sleep 10
########
# Cau hinh ntp
cp /etc/ntp.conf /etc/ntp.conf.bka
rm /etc/ntp.conf
cat /etc/ntp.conf.bka | grep -v ^# | grep -v ^$ >> /etc/ntp.conf
#
sed -i 's/server/#server/' /etc/ntp.conf
echo "server controller" >> /etc/ntp.conf

echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
sysctl -p
#
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-$(uname -r)

#
touch /etc/kernel/postinst.d/statoverride

#
cat << EOF >> /etc/kernel/postinst.d/statoverride
"#!/bin/sh"
echoversion="$1"
# passing the kernel version is required
[ -z "${version}" ] && exit 0
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-${version}
EOF

chmod +x /etc/kernel/postinst.d/statoverride
########
echo "############ Cau hinh nova.conf ############"
sleep 5
########
#/* Sao luu truoc khi sua file nova.conf
filenova=/etc/nova/nova.conf
test -f $filenova.orig || cp $filenova $filenova.orig

#Chen noi dung file /etc/nova/nova.conf vao 
cat << EOF > $filenova
[DEFAULT]
verbose = True
network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
neutron_url = http://controller:9696
neutron_auth_strategy = keystone
neutron_admin_tenant_name = service
neutron_admin_username = neutron
neutron_admin_password = $ADMIN_PASS
neutron_admin_auth_url = http://controller:35357/v2.0
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver
security_group_api = neutron
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
iscsi_helper=tgtadm
libvirt_use_virtio_for_bridges=True
connection_type=libvirt
root_helper=sudo nova-rootwrap /etc/nova/rootwrap.conf
verbose=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
volumes_path=/var/lib/nova/volumes
enabled_apis=ec2,osapi_compute,metadata
auth_strategy = keystone
rpc_backend = rabbit
rabbit_host = controller
rabbit_password = $RABBIT_PASS

# Chen password cho VM
libvirt_inject_password = True
libvirt_inject_partition = -1
enable_instance_password = True

my_ip = $COM1_MGNT_IP
vnc_enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $COM1_MGNT_IP
novncproxy_base_url = http://$CON_EXT_IP:6080/vnc_auto.html
glance_host = controller
volume_api_class=nova.volume.cinder.API
osapi_volume_listen_port=5900
cinder_catalog_info=volume:cinder:internalURL

# Cho phep thay doi kich thuoc may ao
allow_resize_to_same_host=True
scheduler_default_filters=AllHostsFilter

[database]
connection = mysql://nova:$ADMIN_PASS@controller/nova
[keystone_authtoken]
auth_uri = http://controller:5000
identity_uri = http://controller:35357
#auth_host = controller
#auth_port = 35357
#auth_protocol = http
admin_tenant_name = service
admin_user = nova
admin_password = $ADMIN_PASS

[neutron]
url = http://controller:9696
auth_strategy = keystone
admin_auth_url = http://controller:35357/v2.0
admin_tenant_name = service
admin_username = neutron
admin_password = $ADMIN_PASS

[libvirt]
virt_type = qemu

EOF


# Xoa file sql mac dinh
rm /var/lib/nova/nova.sqlite


# fix loi libvirtError: internal error: no supported architecture for os type 'kvm'
echo 'kvm_intel' >> /etc/modules
 
# Khoi dong lai nova
service nova-compute restart
service nova-compute restart

########
echo "############ Cai dat neutron agent ############"
sleep 5
########
# Cai dat neutron agent
apt-get install neutron-plugin-ml2 neutron-plugin-openvswitch-agent -y

##############################
echo "############ Cau hinh neutron.conf ############"
sleep 5
#############################
comfileneutron=/etc/neutron/neutron.conf
test -f $comfileneutron.orig || cp $comfileneutron $comfileneutron.orig
rm $comfileneutron
#Chen noi dung file /etc/neutron/neutron.conf
 
cat << EOF > $comfileneutron
[DEFAULT]
auth_strategy = keystone
rpc_backend = neutron.openstack.common.rpc.impl_kombu
rabbit_host = controller
rabbit_password = $RABBIT_PASS
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
verbose = True
state_path = /var/lib/neutron
lock_path = \$state_path/lock
notification_driver = neutron.openstack.common.notifier.rpc_notifier

[quotas]

[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://controller:5000
identity_uri = http://controller:35357
#auth_host = controller
#auth_protocol = http
#auth_port = 35357
admin_tenant_name = service
admin_user = neutron
admin_password = $ADMIN_PASS
signing_dir = \$state_path/keystone-signing

[database]
# connection = sqlite:////var/lib/neutron/neutron.sqlite

[service_providers]
EOF
#

########
echo "############ Cau hinh ml2_conf.ini ############"
sleep 5
########
comfileml2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $comfileml2.orig || cp $comfileml2 $comfileml2.orig
rm $comfileml2
touch $comfileml2
#Chen noi dung file  vao /etc/neutron/plugins/ml2/ml2_conf.ini
cat << EOF > $comfileml2
[ml2]
type_drivers = flat,gre
tenant_network_types = gre
mechanism_drivers = openvswitch

[ml2_type_flat]

[ml2_type_vlan]

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]

[ovs]
local_ip = $COM1_DATA_VM_IP
enable_tunneling = True

[agent]
tunnel_types = gre

[securitygroup]
enable_ipset = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
enable_security_group = True

EOF

# Khoi dong lai OpenvSwitch
########
echo "############ Khoi dong lai OpenvSwitch ############"
sleep 5
########
service openvswitch-switch restart


########
echo "############ Tao integration bridge ############"
sleep 5
########
# Tao integration bridge
ovs-vsctl add-br br-int


# fix loi libvirtError: internal error: no supported architecture for os type 'hvm'
echo 'kvm_intel' >> /etc/modules

##########
echo "############ Khoi dong lai Compute ############"
sleep 5

########
# Khoi dong lai Compute
service nova-compute restart
service nova-compute restart

########
echo "############ Khoi dong lai Openvswitch agent ############"
sleep 5
########
# Khoi dong lai Openvswitch agent
service neutron-plugin-openvswitch-agent restart
service neutron-plugin-openvswitch-agent restart

echo "########## TAO FILE CHO BIEN MOI TRUONG ##########"
sleep 5
echo "export OS_USERNAME=admin" > admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS" >> admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://controller:35357/v2.0" >> admin-openrc.sh

########
echo "############ KIEM TRA LAI NOVA va NEUTRON ############"
sleep 5
########
source admin-openrc.sh
nova-manage service list
neutron agent-list