#!/bin/bash

source os.conf
source admin-openrc

##### Nova Compute Service #####
mysql -u root -p$PASSWORD -e "SHOW DATABASES;" | grep nova > /dev/null 2>&1 && echo "nova database exists"
if [ $? -ne 0 ]
  then
    mysql -u root -p$PASSWORD -e "CREATE DATABASE nova; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$PASSWORD';"
  fi

mysql -u root -p$PASSWORD -e "SHOW DATABASES;" | grep nova_api > /dev/null 2>&1 && echo "nova_api database exists"
if [ $? -ne 0 ]
  then
    mysql -u root -p$PASSWORD -e "CREATE DATABASE nova_api; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$PASSWORD';"
  fi

openstack user list | grep nova > /dev/null 2>&1 && echo "nova user exists"
if [ $? -ne 0 ]
  then
    openstack user create --domain default --password $PASSWORD nova
fi
openstack role add --project service --user nova admin

openstack service list | grep nova > /dev/null 2>&1 && echo "nova service exists"
if [ $? -ne 0 ]
  then
    openstack service create --name nova --description "OpenStack Compute service" compute
fi

openstack endpoint list | grep public | grep nova > /dev/null 2>&1 && echo "nova public endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne compute public http://$HOSTNAME:8774/v2.1/%\(tenant_id\)s
fi

openstack endpoint list | grep internal | grep nova > /dev/null 2>&1 && echo "nova internal endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne compute internal http://$HOSTNAME:8774/v2.1/%\(tenant_id\)s
fi

openstack endpoint list | grep admin | grep nova > /dev/null 2>&1 && echo "nova admin endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne compute admin http://$HOSTNAME:8774/v2.1/%\(tenant_id\)s
fi
zypper -n in --no-recommends openstack-nova-api openstack-nova-scheduler openstack-nova-conductor openstack-nova-consoleauth openstack-nova-novncproxy iptables openstack-nova-compute genisoimage kvm libvirt

[ ! -f /etc/nova/nova.conf.orig ] && cp -v /etc/nova/nova.conf /etc/nova/nova.conf.orig
cat << _EOF_ > /etc/nova/nova.conf
[DEFAULT]
log_dir = /var/log/nova
connection_type = libvirt
compute_driver = libvirt.LibvirtDriver
image_service = nova.image.glance.GlanceImageService
volume_api_class = nova.volume.cinder.API
auth_strategy = keystone
bindir = /usr/bin
state_path = /var/lib/nova
service_neutron_metadata_proxy = True
use_neutron = True
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$PASSWORD@$HOSTNAME
my_ip = $IPMAN
firewall_driver = nova.virt.firewall.NoopFirewallDriver

[api_database]
connection = mysql+pymysql://nova:$PASSWORD@$HOSTNAME/nova_api

[database]
connection = mysql+pymysql://nova:$PASSWORD@$HOSTNAME/nova

[keystone_authtoken]
auth_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:35357
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = nova
password = $PASSWORD

[neutron]
url = http://$HOSTNAME:9696
auth_url = http://$HOSTNAME:35357
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $PASSWORD
service_metadata_proxy = True
metadata_proxy_shared_secret = $PASSWORD

[oslo_concurrency]
lock_path = /var/run/nova

[vnc]
vncserver_listen = $my_ip
vncserver_proxyclient_address = $my_ip
enabled = True
novncproxy_base_url = http://$my_ip:6080/vnc_auto.html

[glance]
api_servers = http://$HOSTNAME:9292

[libvirt]
virt_type = qemu
_EOF_

modprobe nbd
echo nbd > /etc/modules-load.d/nbd.conf

systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service
systemctl restart openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service
systemctl status openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service libvirtd.service openstack-nova-compute.service
sleep 10
openstack compute service list
