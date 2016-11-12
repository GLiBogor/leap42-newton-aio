#!/bin/bash

source os.conf
source admin-openrc

##### Cinder Block Storage Service #####
IDDISK=`lsblk | head -2 | tail -1 | cut -d" " -f1`

mysql -u root -p$PASSWORD -e "SHOW DATABASES;" | grep cinder > /dev/null 2>&1 && echo "cinder database exists"
if [ $? -ne 0 ]
  then
    mysql -u root -p$PASSWORD -e "CREATE DATABASE cinder; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$PASSWORD';"
  fi

openstack user list | grep cinder > /dev/null 2>&1 && echo "cinder user exists"
if [ $? -ne 0 ]
  then
    openstack user create --domain default --password $PASSWORD cinder
fi
openstack role add --project service --user cinder admin

openstack service list | grep cinder > /dev/null 2>&1 && echo "cinder service exists"
if [ $? -ne 0 ]
  then
    openstack service create --name cinder --description "OpenStack Block Storage service" volume
fi

openstack service list | grep cinderv2 > /dev/null 2>&1 && echo "cinderv2 service exists"
if [ $? -ne 0 ]
  then
    openstack service create --name cinderv2 --description "OpenStack Block Storage service" volumev2
fi

openstack endpoint list | grep public | grep cinder > /dev/null 2>&1 && echo "cinder or cinderv2 public endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne volume public http://$HOSTNAME:8776/v1/%\(tenant_id\)s
fi

openstack endpoint list | grep internal | grep cinder > /dev/null 2>&1 && echo "cinder or cinderv2 internal endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne volume internal http://$HOSTNAME:8776/v1/%\(tenant_id\)s
fi

openstack endpoint list | grep admin | grep cinder > /dev/null 2>&1 && echo "cinder or cinderv2 admin endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne volume admin http://$HOSTNAME:8776/v1/%\(tenant_id\)s
fi

openstack endpoint list | grep public | grep cinderv2 > /dev/null 2>&1 && echo "cinder or cinderv2 public endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne volumev2 public http://$HOSTNAME:8776/v2/%\(tenant_id\)s
fi

openstack endpoint list | grep internal | grep cinderv2 > /dev/null 2>&1 && echo "cinder or cinderv2 internal endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne volumev2 internal http://$HOSTNAME:8776/v2/%\(tenant_id\)s
fi

openstack endpoint list | grep admin | grep cinderv2 > /dev/null 2>&1 && echo "cinder or cinderv2 admin endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne volumev2 admin http://$HOSTNAME:8776/v2/%\(tenant_id\)s
fi

zypper -n in --no-recommends openstack-cinder-api openstack-cinder-scheduler lvm2 qemu openstack-cinder-volume tgt

[ ! -f /etc/cinder/cinder.conf.orig ] && cp -v /etc/cinder/cinder.conf /etc/cinder/cinder.conf.orig
cat << _EOF_ > /etc/cinder/cinder.conf
[DEFAULT]
verbose = True
log_dir = /var/log/cinder
auth_strategy = keystone
rootwrap_config = /etc/cinder/rootwrap.conf
state_path = /var/lib/cinder
volume_group = cinder-volumes
lvm_type = thin
lock_path = /var/lib/cinder/tmp
transport_url = rabbit://openstack:$PASSWORD@$HOSTNAME
my_ip = $IPMAN
enabled_backends = lvm
glance_api_servers = http://$HOSTNAME:9292

[database]
connection = mysql+pymysql://cinder:$PASSWORD@$HOSTNAME/cinder

[keystone_authtoken]
auth_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:35357
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = $PASSWORD

[oslo_concurrency]
lock_path = /var/lib/cinder/tmp

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = tgtadm
_EOF_

pvs | grep "/dev/${IDDISK}6" > /dev/null 2>&1 && echo "PV /dev/${IDDISK}6 exists"
if [ $? -ne 0 ]
  then
    pvcreate /dev/${IDDISK}6
    pvs
fi
vgcreate cinder-volumes /dev/${IDDISK}6

echo "include /var/lib/cinder/volumes/*" > /etc/tgt/conf.d/cinder.conf

systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service tgtd.service
systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service tgtd.service
systemctl status openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service tgtd.service
sleep 10
openstack volume service list
