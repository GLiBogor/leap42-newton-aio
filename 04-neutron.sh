#!/bin/bash

source os.conf
source admin-openrc

##### Nutron Networking Service #####
mysql -u root -p$PASSWORD -e "SHOW DATABASES;" | grep neutron > /dev/null 2>&1 && echo "neutron database exists"
if [ $? -ne 0 ]
  then
    mysql -u root -p$PASSWORD -e "CREATE DATABASE neutron; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$PASSWORD';"
fi

openstack user list | grep neutron > /dev/null 2>&1 && echo "neutron user exists"
if [ $? -ne 0 ]
  then
    openstack user create --domain default --password $PASSWORD neutron
fi
openstack role add --project service --user neutron admin

openstack service list | grep neutron > /dev/null 2>&1 && echo "neutron service exists"
if [ $? -ne 0 ]
  then
    openstack service create --name neutron --description "OpenStack Networking service" network
fi

openstack endpoint list | grep public | grep neutron > /dev/null 2>&1 && echo "neutron public endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne network public http://$HOSTNAME:9696
fi

openstack endpoint list | grep internal | grep neutron > /dev/null 2>&1 && echo "neutron internal endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne network internal http://$HOSTNAME:9696
fi

openstack endpoint list | grep admin | grep neutron > /dev/null 2>&1 && echo "neutron admin endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne neutron admin http://$HOSTNAME:9696
fi

zypper -n in --no-recommends openstack-neutron openstack-neutron-server openstack-neutron-linuxbridge-agent openstack-neutron-l3-agent openstack-neutron-dhcp-agent openstack-neutron-metadata-agent bridge-utils

[ ! -f /etc/neutron/neutron.conf.orig ] && cp -v /etc/neutron/neutron.conf /etc/neutron/neutron.conf.orig
cat << _EOF_ > /etc/neutron/neutron.conf
[DEFAULT]
verbose = True
core_plugin = ml2
service_plugins = router
state_path = /var/lib/neutron
log_dir = /var/log/neutron
allow_overlapping_ips = True
transport_url = rabbit://openstack:$PASSWORD@$HOSTNAME
auth_strategy = keystone
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True

[agent]
root_helper = sudo neutron-rootwrap /etc/neutron/rootwrap.conf

[oslo_concurrency]
lock_path = /var/run/neutron

[keystone_authtoken]
auth_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:35357
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $PASSWORD

[database]
connection = mysql+pymysql://neutron:$PASSWORD@$HOSTNAME/neutron

[nova]
auth_url = http://$HOSTNAME:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $PASSWORD
_EOF_

[ ! -f /etc/neutron/plugins/ml2/ml2_conf.ini.orig ] && cp -v /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.orig
cat << _EOF_ > /etc/neutron/plugins/ml2/ml2_conf.ini
[DEFAULT]

[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = external

[ml2_type_vxlan]
vni_ranges = 1:1000

[securitygroup]
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
enable_ipset = True
_EOF_

[ ! -f /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig ] && cp -v /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.orig
cat << _EOF_ > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
[DEFAULT]

[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

[linux_bridge]
physical_interface_mappings = external:$INTEXT

[vxlan]
enable_vxlan = True
local_ip = $IPMAN
l2_population = True
_EOF_

[ ! -f /etc/neutron/l3_agent.ini.orig ] && cp -v /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.orig
cat << _EOF_ > /etc/neutron/l3_agent.ini
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
external_network_bridge = 
_EOF_

[ ! -f /etc/neutron/dhcp_agent.ini.orig ] && cp -v /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.orig
cat << _EOF_ > /etc/neutron/dhcp_agent.ini
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
dhcp_delete_namespaces = True
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True
_EOF_

[ ! -f /etc/neutron/metadata_agent.ini.orig ] && cp -v /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.orig
cat << _EOF_ > /etc/neutron/metadata_agent.ini
[DEFAULT]
nova_metadata_ip = $HOSTNAME
metadata_proxy_shared_secret = $PASSWORD
_EOF_

systemctl enable openstack-neutron.service openstack-neutron-linuxbridge-agent.service openstack-neutron-dhcp-agent.service openstack-neutron-metadata-agent.service openstack-neutron-l3-agent.service
systemctl restart openstack-neutron.service openstack-neutron-linuxbridge-agent.service openstack-neutron-dhcp-agent.service openstack-neutron-metadata-agent.service openstack-neutron-l3-agent.service
systemctl status openstack-neutron.service openstack-neutron-linuxbridge-agent.service openstack-neutron-dhcp-agent.service openstack-neutron-metadata-agent.service openstack-neutron-l3-agent.service

neutron ext-list
openstack network agent list
