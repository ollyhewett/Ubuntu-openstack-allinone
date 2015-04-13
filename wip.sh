
#!/bin/bash
############################################
#stack information
CONTROLLER_IP=192.168.0.103
ADMIN_TOKEN=passwordhere
SERVICE_PWD=passwordhere
ADMIN_PWD=passwordhere
META_PWD=passwordhere

echo "$(tput setaf 1)STARTING OPENSTACKING INSTALL$(tput sgr0)"


#sets hosts file
sed -i "s/127.0.1.1/$CONTROLLER_IP/g" /etc/hosts
echo "$(tput setaf 1)HOST FILE CHANGED$(tput sgr0)"


#Package depandanies
echo "$(tput setaf 1)INSTALLING CORE DEPENDANCIES$(tput sgr0)"
apt-get install ntp -y
apt-get install crudini -y
apt-get install python-software-properties -y
apt-get install ubuntu-cloud-keyring -y
echo "deb http://ubuntu-cloud.archive.canonical.com/ubuntu" \
  "trusty-updates/juno main" > /etc/apt/sources.list.d/cloudarchive-juno.list
apt-get install -y ntp vlan bridge-utils -y
apt-get update && apt-get dist-upgrade -y
echo "$(tput setaf 1)INSTALL CORE DEPENDANCIES COMPLETED$(tput sgr0)"

#Change forwarding
echo "$(tput setaf 1)CHANGING SYSCTL$(tput sgr0)"
sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sed -i -e 's/#net.ipv4.conf.all.rp_filter=1/net.ipv4.conf.all.rp_filter=0/g' /etc/sysctl.conf
sed -i -e 's/#net.ipv4.conf.default.rp_filter=1/net.ipv4.conf.default.rp_filter=0/g' /etc/sysctl.conf
sysctl -p
echo "$(tput setaf 1)SYSCTL CHANGED$(tput sgr0)"



#INSTALL RABBITMQ
echo "$(tput setaf 1)INSTALLING RABBITMQ$(tput sgr0)"
apt-get install -y rabbitmq-server
rabbitmqctl change_password guest $SERVICE_PWD
service rabbitmq-server restart
echo "$(tput setaf 1)RABBITMQ INSTALLED$(tput sgr0)"

#install db
echo "$(tput setaf 1)INSTALLING MYSQL$(tput sgr0)"
apt-get install mariadb-server python-mysqldb -y
sed -i "s/bind-address.*/bind-address = $CONTROLLER_IP/" /etc/mysql/my.cnf
sed -i '/skip-external-locking/a character-set-server = utf8' /etc/mysql/my.cnf
sed -i "/skip-external-locking/a init-connect = 'SET NAMES utf8'" /etc/mysql/my.cnf
sed -i '/skip-external-locking/a collation-server = utf8_general_ci' /etc/mysql/my.cnf
sed -i '/skip-external-locking/a innodb_file_per_table' /etc/mysql/my.cnf
sed -i '/skip-external-locking/a default-storage-engine = innodb' /etc/mysql/my.cnf
echo 'Enter the new MySQL root password'
mysql -u root -p$ADMIN_PWD <<EOF
CREATE DATABASE nova;
CREATE DATABASE cinder;
CREATE DATABASE glance;
CREATE DATABASE keystone;
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$SERVICE_PWD';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$SERVICE_PWD';
FLUSH PRIVILEGES;
EOF

service mysql restart
echo "$(tput setaf 1)MYSQL INSTALLED$(tput sgr0)"



#INSTALL Keystone
echo "$(tput setaf 1)INSTALLING KEYSTONE$(tput sgr0)"
apt-get install -y keystone
crudini --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_PWD
crudini --set /etc/keystone/keystone.conf database connection mysql://keystone:$ADMIN_PWD@$CONTROLLER_IP/keystone
crudini --set /etc/keystone/keystone.conf token provider keystone.token.providers.uuid.Provider
crudini --set /etc/keystone/keystone.conf token driver keystone.token.persistence.backends.sql.Token
crudini --set /etc/keystone/keystone.conf DEFAULT verbose true
su -s /bin/sh -c "keystone-manage db_sync" keystone

service keystone restart

rm -f /var/lib/keystone/keystone.db

(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
  echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' \
  >> /var/spool/cron/crontabs/keystone

sleep 5
echo "$(tput setaf 1)INSTALLED KEYSTONE$(tput sgr0)"


#create users and tenants
echo "$(tput setaf 1)CREATING KEYSTONE USERS AND TENANTS$(tput sgr0)"
export OS_SERVICE_TOKEN=$ADMIN_TOKEN
export OS_SERVICE_ENDPOINT=http://$CONTROLLER_IP:35357/v2.0
sleep 5

keystone tenant-create --name admin --description "Admin Tenant"
keystone user-create --name admin --pass $ADMIN_PWD
keystone role-create --name admin
keystone user-role-add --tenant admin --user admin --role admin
keystone role-create --name _member_
keystone user-role-add --tenant admin --user admin --role _member_
keystone tenant-create --name demo --description "Demo Tenant"
keystone user-create --name demo --pass $ADMIN_PWD
keystone user-role-add --tenant demo --user demo --role _member_
keystone tenant-create --name service --description "Service Tenant"
keystone service-create --name keystone --type identity \
  --description "OpenStack Identity"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ identity / {print $2}') \
  --publicurl http://$CONTROLLER_IP:5000/v2.0 \
  --internalurl http://$CONTROLLER_IP:5000/v2.0 \
  --adminurl http://$CONTROLLER_IP:35357/v2.0 \
  --region regionOne
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT
echo "$(tput setaf 1)CREATING KEYSTONE USERS AND TENANTS$(tput sgr0)"

#create credentials file
echo "export OS_TENANT_NAME=admin" > creds
echo "export OS_USERNAME=admin" >> creds
echo "export OS_PASSWORD=$ADMIN_PWD" >> creds
echo "export OS_AUTH_URL=http://$CONTROLLER_IP:35357/v2.0" >> creds
source creds
echo "$(tput setaf 1)CREDENTAILS FILES CREATED$(tput sgr0)"


#create keystone entries for glance
echo "$(tput setaf 1)CREATING GLANCE USERS AND TENANTS AND CONF$(tput sgr0)"

keystone user-create --name glance --pass $SERVICE_PWD
keystone user-role-add --user glance --tenant service --role admin
keystone service-create --name glance --type image \
  --description "OpenStack Image Service"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ image / {print $2}') \
  --publicurl http://$CONTROLLER_IP:9292 \
  --internalurl http://$CONTROLLER_IP:9292 \
  --adminurl http://$CONTROLLER_IP:9292 \
  --region regionOne
  
 apt-get install -y glance
  
#crudini --set /etc/glance/glance-api.conf database connection mysql://glance:$ADMIN_PWD@$CONTROLLER_IP/glance
#crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
#crudini --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://$CONTROLLER_IP:35357
#crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_tenant_name service
#crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_user  glance
#crudini --set /etc/glance/glance-api.conf keystone_authtoken admin_password  $ADMIN_PWD
#crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
#crudini --set /etc/glance/glance-api.conf glance_store default_store file
#crudini --set /etc/glance/glance-api.conf filesystem_store_datadir  /var/lib/glance/images/
#crudini --set /etc/glance/glance-api.conf DEFAULT verbose True

crudini --set /etc/glance/glance-registry.conf database connection mysql://glance:$ADMIN_PWD@$CONTROLLER_IP/glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
crudini --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri  http://$CONTROLLER_IP:35357
crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_tenant_name  service
crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_user  glance
crudini --set /etc/glance/glance-registry.conf keystone_authtoken admin_password  $ADMIN_PWD
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-registry.conf DEFAULT verbose True

su -s /bin/sh -c "glance-manage db_sync" glance
echo "$(tput setaf 1)CREATED GLANCE USERS AND TENANTS AND CONF$(tput sgr0)"


wget http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
glance image-create --name "cirros-0.3.3-x86_64" --file cirros-0.3.3-x86_64-disk.img \
  --disk-format qcow2 --container-format bare --is-public True --progress
echo "$(tput setaf 1)DEMO OS INSTALLED$(tput sgr0)"

#mkdir /tmp/images
#cd /tmp/images
#wget http://cdn.download.cirros-cloud.net/0.3.3/cirros-0.3.3-x86_64-disk.img
#cd ~
#glance image-create --name "cirros-0.3.3-x86_64" --file /tmp/images/cirros-0.3.3-x86_64-disk.img \
#  --disk-format qcow2 --container-format bare --is-public True --progress

###needs work  

echo "$(tput setaf 1)CONFIGURATING FOR NOVA$(tput sgr0)"
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth nova-novncproxy nova-scheduler python-novaclient nova-compute nova-console

keystone user-create --name nova --pass $ADMIN_PWD
  
keystone user-role-add --user nova --tenant service --role admin

keystone service-create --name nova --type compute \
  --description "OpenStack Compute"


keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ compute / {print $2}') \
  --publicurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --internalurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --adminurl http://$CONTROLLER_IP:8774/v2/%\(tenant_id\)s \
  --region regionOne
  
  
  
crudini --set /etc/nova/nova.conf database connection mysql://nova:$ADMIN_PWD@$CONTROLLER_IP/nova

crudini --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
crudini --set /etc/nova/nova.conf DEFAULT rabbit_host $CONTROLLER_IP
crudini --set /etc/nova/nova.conf DEFAULT rabbit_password $ADMIN_PWD
crudini --set /etc/nova/nova.conf DEFAULT my_ip 192.168.0.71
crudini --set /etc/nova/nova.conf DEFAULT vncserver_listen 192.168.0.71
crudini --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address 192.168.0.71
crudini --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
crudini --set /etc/nova/nova.conf DEFAULT verbose True
crudini --set /etc/nova/nova.conf DEFAULT novncproxy_base_url http://192.168.0.71:6080/vnc_auto.html
crudini --set /etc/nova/nova.conf DEFAULT network_api_class nova.network.neutronv2.api.API
crudini --set /etc/nova/nova.conf DEFAULT security_group_api neutron
crudini --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
crudini --set /etc/nova/nova.conf keystone_authtoken identity_uri  http://$CONTROLLER_IP:35357
crudini --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name  service
crudini --set /etc/nova/nova.conf keystone_authtoken admin_user nova
crudini --set /etc/nova/nova.conf keystone_authtoken admin_password $ADMIN_PWD

crudini --set /etc/nova/nova.conf glance host $CONTROLLER_IP

crudini --set /etc/nova/nova.conf neutron service_metadata_proxy True
crudini --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $ADMIN_PWD

crudini --set /etc/nova/nova.conf neutron url http://$CONTROLLER_IP:9696
crudini --set /etc/nova/nova.conf neutron auth_strategy keystone
crudini --set /etc/nova/nova.conf neutron admin_auth_url http://$CONTROLLER_IP:35357/v2.0
crudini --set /etc/nova/nova.conf neutron admin_tenant_name service
crudini --set /etc/nova/nova.conf neutron admin_username neutron
crudini --set /etc/nova/nova.conf neutron admin_password $ADMIN_PWD

crudini --set /etc/nova/nova.conf DEFAULT vif_plugging_is_fatal False
crudini --set /etc/nova/nova.conf DEFAULT vif_plugging_timeout 0

su -s /bin/sh -c "nova-manage db sync" nova

service nova-api restart ;service nova-cert restart; service nova-consoleauth restart ;service nova-scheduler restart;service nova-conductor restart; service nova-novncproxy restart; service nova-compute restart; service nova-console restart

######testing nova-manage service list  & nova list

rm -f /var/lib/nova/nova.sqlite

#######################network installation

echo "$(tput setaf 1)CONFIGURATING FOR NEUTRON$(tput sgr0)"
apt-get install -y neutron-server neutron-plugin-openvswitch neutron-plugin-openvswitch-agent neutron-common neutron-dhcp-agent neutron-l3-agent neutron-metadata-agent openvswitch-switch

source admin-openrc.sh
  
  keystone user-create --name neutron --pass $ADMIN_PWD
  keystone user-role-add --user neutron --tenant service --role admin
  keystone service-create --name neutron --type network \
  --description "OpenStack Networking"
  
  
  keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ network / {print $2}') \
  --publicurl http://$CONTROLLER_IP:9696 \
  --adminurl http://$CONTROLLER_IP:9696 \
  --internalurl http://$CONTROLLER_IP:9696 \
  --region regionOne
  
SERVICE_TENANT_ID=$(keystone tenant-list | awk '/ service / {print $2}')
 
crudini --set /etc/neutron/neutron.conf database connection mysql://neutron:$ADMIN_PWD@$CONTROLLER_IP/neutron

crudini --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_host $CONTROLLER_IP
crudini --set /etc/neutron/neutron.conf DEFAULT rabbit_password $ADMIN_PWD
crudini --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
crudini --set /etc/neutron/neutron.conf DEFAULT core_plugin ml2
crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins router
crudini --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips True
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes True
crudini --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes True
crudini --set /etc/neutron/neutron.conf DEFAULT nova_url http://$CONTROLLER_IP:8774/v2
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_auth_url http://$CONTROLLER_IP:35357/v2.0
crudini --set /etc/neutron/neutron.conf DEFAULT nova_region_name regionOne
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_username nova
#check# crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id 7cd1ec1e2ea741999a454c9785b7fbe0
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_tenant_id $SERVICE_TENANT_ID
crudini --set /etc/neutron/neutron.conf DEFAULT nova_admin_password $ADMIN_PWD
crudini --set /etc/neutron/neutron.conf DEFAULT verbose True 

crudini --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$CONTROLLER_IP:5000/v2.0
crudini --set /etc/neutron/neutron.conf keystone_authtoken identity_uri  http://$CONTROLLER_IP:35357
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_user neutron
crudini --set /etc/neutron/neutron.conf keystone_authtoken admin_password $ADMIN_PWD


crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,vlan
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types vlan,flat
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks External
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_vlan network_vlan_ranges Intnet1:100:200
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
##BUGFIX
crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings External:br-ex,Intnet1:br-int
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings External:br-ex,Intnet1:br-eth1


#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers flat,gre
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types gre
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers openvswitch
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges 1:1000
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group True
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset True
#crudini --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver



crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_url http://$CONTROLLER_IP:5000/v2.0
crudini --set /etc/neutron/metadata_agent.ini DEFAULT auth_region regionOne
crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_tenant_name service
crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_user neutron
crudini --set /etc/neutron/metadata_agent.ini DEFAULT admin_password $ADMIN_PWD
crudini --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret $ADMIN_PWD

crudini --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT use_namespaces True
crudini --set /etc/neutron/dhcp_agent.ini DEFAULT verbose True

crudini --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set /etc/neutron/l3_agent.ini DEFAULT use_namespaces True
crudini --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge br-ex
crudini --set /etc/neutron/l3_agent.ini DEFAULT verbose True


#######################BRIDGE CONFIGURATION

echo "$(tput setaf 1)CONFIGURATING OPENVSWITCH$(tput sgr0)"

ovs-vsctl add-br br-int
ovs-vsctl add-br br-eth2
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-eth2 eth2
ovs-vsctl add-port br-ex eth1

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron

service neutron-server restart; service neutron-plugin-openvswitch-agent restart;service neutron-metadata-agent restart; service neutron-dhcp-agent restart; service neutron-l3-agent restart

neutron net-create ext-net --router:external True   --provider:physical_network External --provider:network_type flat


#######################VIRTUAL CONFIGURATION
echo "$(tput setaf 1)CREATING VIRTUAL NETWORK CONF$(tput sgr0)"

neutron subnet-create ext-net --name ext-subnet \
  --allocation-pool start=192.168.3.200,end=192.168.3.240 \
  --disable-dhcp --gateway 192.168.3.1 192.168.3.0/24

neutron net-create internal-net
neutron subnet-create internal-net --name internal-subnet \
  --gateway 10.0.0.1 10.0.0.0/24

neutron router-create internal-router
neutron router-interface-add internal-router internal-subnet
neutron router-gateway-set internal-router ext-net

#######################HORIZON CONFIGURATION
echo "$(tput setaf 1)INSTALLING HORIZON AND CONF$(tput sgr0)"

apt-get install openstack-dashboard apache2 libapache2-mod-wsgi memcached python-memcache -y
apt-get remove --purge openstack-dashboard-ubuntu-theme -y
