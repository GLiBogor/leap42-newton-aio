#!/bin/bash

source os.conf
source admin-openrc

##### Glance Image Service #####
mysql -u root -p$PASSWORD -e "SHOW DATABASES;" | grep glance > /dev/null 2>&1 && echo "glance database exists"
if [ $? -ne 0 ]
  then
    mysql -u root -p$PASSWORD -e "CREATE DATABASE glance; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$PASSWORD'; GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$PASSWORD';"
  fi

openstack user list | grep glance > /dev/null 2>&1 && echo "glance user exists"
if [ $? -ne 0 ]
  then
    openstack user create --domain default --password $PASSWORD glance
fi
openstack role add --project service --user glance admin

openstack service list | grep glance > /dev/null 2>&1 && echo "glance service exists"
if [ $? -ne 0 ]
  then
    openstack service create --name glance --description "OpenStack Image service" image
fi

openstack endpoint list | grep public | grep glance > /dev/null 2>&1 && echo "glance public endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne image public http://$HOSTNAME:9292
fi

openstack endpoint list | grep internal | grep glance > /dev/null 2>&1 && echo "glance internal endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne image internal http://$HOSTNAME:9292
fi

openstack endpoint list | grep admin | grep glance > /dev/null 2>&1 && echo "glance admin endpoint exists"
if [ $? -ne 0 ]
  then
    openstack endpoint create --region RegionOne image admin http://$HOSTNAME:9292
fi
zypper -n in --no-recommends openstack-glance openstack-glance-api openstack-glance-registry

[ ! -f /etc/glance/glance-api.conf.orig ] && cp -v /etc/glance/glance-api.conf /etc/glance/glance-api.conf.orig
cat << _EOF_ > /etc/glance/glance-api.conf
[DEFAULT]
verbose = True
log_dir = /var/log/glance
notification_driver = messaging
lock_path = /var/run/glance


[database]
connection = mysql+pymysql://glance:$PASSWORD@$HOSTNAME/glance


[glance_store]
filesystem_store_datadir = /var/lib/glance/images/
stores = file,http
default_store = file


[keystone_authtoken]
signing_dir = /var/cache/glance/keystone-signing
auth_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:35357
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = glance
password = $PASSWORD


[paste_deploy]
flavor = keystone
_EOF_

[ ! -f /etc/glance/glance-registry.conf.orig ] && cp -v /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.orig
cat << _EOF_ > /etc/glance/glance-registry.conf
[DEFAULT]
verbose = True
log_dir = /var/log/glance

[database]
connection = mysql+pymysql://glance:$PASSWORD@$HOSTNAME/glance

[keystone_authtoken]
auth_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:35357
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = glance
password = $PASSWORD

[paste_deploy]
flavor = keystone
_EOF_

systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
systemctl status openstack-glance-api.service openstack-glance-registry.service
glance image-list
