
#####Controller

auto eth0
iface eth0 inet static
address 10.0.0.11
netmask 255.255.255.0
dns-nameservers 8.8.8.8

auto eth1
iface eth1 inet dhcp


#####network

auto eth0
iface eth0 inet static
address 10.0.0.21
netmask 255.255.255.0
dns-nameservers 8.8.8.8

auto eth1
iface eth1 inet static
address 10.0.1.21
netmask 255.255.255.0

auto eth2
iface eth2 inet manual
        up ip link set dev $IFACE up
        down ip link set dev $IFACE down

auto eth3
iface eth3 inet dhcp



#####compute1

auto eth0
iface eth0 inet static
address 10.0.0.31
netmask 255.255.255.0
dns-nameservers 8.8.8.8

auto eth1
iface eth1 inet static
address 10.0.1.31
netmask 255.255.255.0

auto eth2
iface eth2 inet static
address 10.0.2.31
netmask 255.255.255.0

auto eth3
iface eth3 inet dhcp



######block1

auto eth0
iface eth0 inet static
address 10.0.0.41
netmask 255.255.255.0
dns-nameservers 8.8.8.8

auto eth1
iface eth1 inet static
address 10.0.1.41
netmask 255.255.255.0

auto eth2
iface eth2 inet dhcp

########object1

auto eth0
iface eth0 inet static
address 10.0.0.51
netmask 255.255.255.0
dns-nameservers 8.8.8.8

auto eth1
iface eth1 inet static
address 10.0.1.51
netmask 255.255.255.0

auto eth2
iface eth2 inet dhcp


apt-get update && apt-get upgrade -y 
apt-get install ntp crudini 

nano /etc/hosts

del 127.0.1.1 entry

10.0.0.11	controller
10.0.0.21	network
10.0.0.31       compute1
10.0.0.41	block1
10.0.0.51	object1
10.0.0.61	compute2




apt-get install ntp -y

apt-get install python-software-properties -y

apt-get install ubuntu-cloud-keyring -y

echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
  "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list

apt-get update && apt-get dist-upgrade -y


#####controller

apt-get install mariadb-server python-mysqldb -y

nano /etc/mysql/my.cnf


apt-get install rabbitmq-server -y


rabbitmqctl change_password guest $password

GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
  IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
  IDENTIFIED BY '$password';


apt-get install keystone python-keystoneclient -y

crudini --set /etc/keystone/keystone.conf DEFAULT admin_token 2b42110213a6200f68cf
crudini --set /etc/keystone/keystone.conf database connection mysql://keystone:$password@controller/keystone
crudini --set /etc/keystone/keystone.conf token provider keystone.token.providers.uuid.Provider
crudini --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.sql.Token
crudini --set /etc/keystone/keystone.conf DEFAULT verbose true


export OS_SERVICE_TOKEN=2b42110213a6200f68cf


keystone user-create --name admin --pass $password --email admin@admin.com

keystone user-create --name demo --pass $password --email admin@admin.com


-----------------------------------------------------------------------------------------------------------------
API endpoint for the Identity service <<--- consideration http://docs.openstack.org/juno/install-guide/install/apt/content/keystone-services.html
-------------------------------------------------------------------------------------------------------------------------

keystone --os-tenant-name admin --os-username admin --os-password $password \
  --os-auth-url http://controller:35357/v2.0 token-get

keystone --os-tenant-name admin --os-username admin --os-password $password \
  --os-auth-url http://controller:35357/v2.0 tenant-list

keystone --os-tenant-name admin --os-username admin --os-password $password \
  --os-auth-url http://controller:35357/v2.0 user-list

keystone --os-tenant-name admin --os-username admin --os-password $password \
  --os-auth-url http://controller:35357/v2.0 role-list

keystone --os-tenant-name demo --os-username demo --os-password $password \
  --os-auth-url http://controller:35357/v2.0 token-get

keystone --os-tenant-name demo --os-username demo --os-password $password \
  --os-auth-url http://controller:35357/v2.0 user-list

--------------------------------------------------------------------------------------

export OS_TENANT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$password
export OS_AUTH_URL=http://controller:35357/v2.0


export OS_TENANT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$password
export OS_AUTH_URL=http://controller:5000/v2.0

---------------------------------------------------------------------------------
####Image Service

GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
  IDENTIFIED BY '$password';

GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
  IDENTIFIED BY '$password';

keystone user-create --name glance --pass $password

-------------------------------------------------------------------------------------

apt-get install glance python-glanceclient -y


crudini --set /etc/glance/glance-api.conf database connection mysql://glance:$password@controller/glance

crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://controller:35357
crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_user  glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_password  $password

crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone


crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf filesystem_store_datadir  /var/lib/glance/images/

crudini --set /etc/glance/glance-api.conf DEFAULT verbose True

crudini --set /etc/glance/glance-registry.conf database connection mysql://glance:$password@controller/glance


crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name  service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_user  glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_password  $password

crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

crudini --set /etc/glance/glance-registry.conf DEFAULT verbose True

 glance image-create --name "cirros-0.3.3-x86_64" --file /tmp/images/cirros-0.3.3-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --is-public True --progress

------------------------------------------------------------------------------
####http://docs.openstack.org/juno/install-guide/install/apt/content/ch_nova.html compute services

GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY '$password';


keystone user-create --name nova --pass $password


apt-get install nova-api nova-cert nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler python-novaclient -y


crudini --set /etc/nova/nova.conf database connection mysql://nova:$password@controller/nova

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf DEFAULT rabbit_host controller
crudini --set /etc/nova/nova.conf DEFAULT rabbit_password $password


crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone

crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/nova/nova.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name  service
crudini --set /etc/nova/nova.conf keystone_authtoken admin_user nova
crudini --set /etc/nova/nova.conf keystone_authtoken admin_password $password

crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.0.0.11

crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 10.0.0.11
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 10.0.0.11
crudini --set /etc/nova/nova.conf glance host controller
crudini --set /etc/nova/nova.conf DEFAULT verbose True

----------------------------------------------------------------
####on compute node
-----------------------------------------------------------------

apt-get install nova-compute sysfsutils -y

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf DEFAULT rabbit_host controller
crudini --set /etc/nova/nova.conf DEFAULT rabbit_password $password

crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone

crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/nova/nova.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/nova/nova.conf keystone_authtoken admin_user nova
crudini --set /etc/nova/nova.conf keystone_authtoken admin_password $password

crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.0.0.31

crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled True
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 10.0.0.31
crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller:6080/vnc_auto.html


crudini --set /etc/nova/nova.conf glance host controller
crudini --set /etc/nova/nova.conf DEFAULT verbose True




--------------------------------------------------------------------------

GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY '$password';


keystone user-create --name neutron --pass $password


crudini --set /etc/neutron/neutron.conf database connection mysql://neutron:$password@controller/neutron

crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_host controller
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password $password

crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/neutron/neutron.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_password $password

crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True

crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
crudini --set /etc/neutron/neutron.conf DEFAULT nova_url http://controller:8774/v2
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://controller:35357/v2.0
crudini --set /etc/neutron/neutron.conf DEFAULT nova_region_name regionOne
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_username nova
~check# crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id 7cd1ec1e2ea741999a454c9785b7fbe0
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_password $password
crudini --set /etc/neutron/neutron.conf DEFAULT verbose True

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

crudini --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
crudini --set /etc/nova/nova.conf DEFAULT security_group_api neutron
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf neutron url http://controller:9696
crudini --set /etc/nova/nova.conf neutron auth_strategy keystone
crudini --set /etc/nova/nova.conf neutron admin_auth_url http://controller:35357/v2.0
crudini --set /etc/nova/nova.conf neutron admin_tenant_name service
crudini --set /etc/nova/nova.conf neutron admin_username neutron
crudini --set /etc/nova/nova.conf neutron admin_password $password

----------------------------------------------------------------------------------------
####neutron node
-----------------------------------------------------------------------------------


crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_host controller
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password $password

crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/neutron/neutron.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_password $password



crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True

crudini --set /etc/neutron/neutron.conf DEFAULT verbose True

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch


crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks external

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip 10.0.1.21
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_type gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings external:br-ex


crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
crudini --set /etc/neutron/l3_agent.ini DEFAULT verbose True

crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT verbose True

OPTIONAL BIT MISSED

crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://controller:5000/v2.0
crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_region regionOne
crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name service
crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $password

crudini --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip controller

crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $password

crudini --set /etc/neutron/metadata_agent.ini DEFAULT verbose True

---------------------------------------------------------------------------
####on controller node !!!!!!!

crudini --set /etc/nova/nova.conf neutron service_metadata_proxy True
crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $password

 service nova-api restart

------------------------------------------------------
####on network
---------------------------------------------
service openvswitch-switch restart
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth2

ethtool -K eth2 gro off

---------------------------------------------------
####compute node
----------------------------------------------------


crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_host controller
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password $password

crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/neutron/neutron.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_password $password



crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True

crudini --set /etc/neutron/neutron.conf DEFAULT verbose True


crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver


crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip 10.0.1.31
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_type gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True


crudini --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
crudini --set /etc/nova/nova.conf DEFAULT security_group_api neutron
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf neutron url http://controller:9696
crudini --set /etc/nova/nova.conf neutron auth_strategy keystone
crudini --set /etc/nova/nova.conf neutron admin_auth_url http://controller:35357/v2.0
crudini --set /etc/nova/nova.conf neutron admin_tenant_name service
crudini --set /etc/nova/nova.conf neutron admin_username neutron
crudini --set /etc/nova/nova.conf neutron admin_password $password



---------------------------------------------------------------------------
####cinder
-----------------------------------------------------------------------------
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' \
  IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' \
  IDENTIFIED BY '$password';


keystone user-create --name cinder --pass $password
 

crudini --set /etc/cinder/cinder.conf database connection mysql://cinder:$password@controller/cinder


crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_host controller
crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_password $password

crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone


crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/cinder/cinder.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_password $password

crudini --set /etc/cinder/cinder.conf DEFAULT my_ip 10.0.0.11

crudini --set /etc/cinder/cinder.conf DEFAULT verbose True

---------------------
####Storage Node
----------------------

crudini --set /etc/cinder/cinder.conf database connection mysql://cinder:$password@controller/cinder

crudini --set /etc/cinder/cinder.conf DEFAULT rpc_backend rabbit
crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_host controller
crudini --set /etc/cinder/cinder.conf DEFAULT rabbit_password $password

crudini --set /etc/cinder/cinder.conf DEFAULT auth_strategy keystone

crudini --set /etc/cinder/cinder.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/cinder/cinder.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_user cinder
crudini --set /etc/cinder/cinder.conf keystone_authtoken admin_password $password

crudini --set /etc/cinder/cinder.conf DEFAULT my_ip 10.0.0.41

crudini --set /etc/cinder/cinder.conf DEFAULT glance_host controller

crudini --set /etc/cinder/cinder.conf DEFAULT verbose True


-----------------------------
####swift 
-------------------------------

keystone user-create --name swift --pass $password


crudini --set /etc/swift/proxy-server.conf DEFAULT  bind_port 8080
crudini --set /etc/swift/proxy-server.conf DEFAULT user swift
crudini --set /etc/swift/proxy-server.conf DEFAULT swift_dir /etc/swift



-----------------------------------------------------------------------
####second compute node
----------------------------------------------------------------------

apt-get install nova-compute sysfsutils -y

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf DEFAULT rabbit_host controller
crudini --set /etc/nova/nova.conf DEFAULT rabbit_password $password

crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone

crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/nova/nova.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/nova/nova.conf keystone_authtoken admin_user nova
crudini --set /etc/nova/nova.conf keystone_authtoken admin_password $password

crudini --set /etc/nova/nova.conf DEFAULT my_ip 10.0.0.61

crudini --set /etc/nova/nova.conf DEFAULT vnc_enabled True
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 10.0.0.61
crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://controller:6080/vnc_auto.html


crudini --set /etc/nova/nova.conf glance host controller
crudini --set /etc/nova/nova.conf DEFAULT verbose True




crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_host controller
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password $password

crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://controller:5000/v2.0
crudini --set /etc/neutron/neutron.conf keystone_authtoken identity_uri  http://controller:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_password $password



crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True

crudini --set /etc/neutron/neutron.conf DEFAULT verbose True


crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000

crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver


crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip 10.0.1.61
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs tunnel_type gre
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs enable_tunneling True


crudini --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
crudini --set /etc/nova/nova.conf DEFAULT security_group_api neutron
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf neutron url http://controller:9696
crudini --set /etc/nova/nova.conf neutron auth_strategy keystone
crudini --set /etc/nova/nova.conf neutron admin_auth_url http://controller:35357/v2.0
crudini --set /etc/nova/nova.conf neutron admin_tenant_name service
crudini --set /etc/nova/nova.conf neutron admin_username neutron
crudini --set /etc/nova/nova.conf neutron admin_password $password
