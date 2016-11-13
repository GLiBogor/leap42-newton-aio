#!/bin/bash

source os.conf
source admin-openrc

##### Swift Object Storage Service #####
IDDISK=`lsblk | head -2 | tail -1 | cut -d" " -f1`

openstack user list | grep swift > /dev/null 2>&1 && echo "swift user already exists" || openstack user create --domain default --password $PASSWORD swift
openstack role add --project service --user swift admin

openstack service list | grep swift > /dev/null 2>&1 && echo "swift service already exists" || openstack service create --name swift --description "Swift Object Storage service" object-store

openstack endpoint list | grep public | grep swift > /dev/null 2>&1 && echo "swift public endpoint already exists" || openstack endpoint create --region RegionOne object-store public http://$HOSTNAME:8080/v1/AUTH_%\(tenant_id\)s

openstack endpoint list | grep internal | grep swift > /dev/null 2>&1 && echo "swift internal endpoint already exists" || openstack endpoint create --region RegionOne object-store internal http://$HOSTNAME:8080/v1/AUTH_%\(tenant_id\)s

openstack endpoint list | grep admin | grep swift > /dev/null 2>&1 && echo "swift admin endpoint already exists" || openstack endpoint create --region RegionOne object-store admin http://$HOSTNAME:8080/v1

echo -n "installing packages... " && zypper -n in --no-recommends openstack-swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware python-xml memcached xfsprogs rsync > /dev/null 2>&1 && echo "done"

[ ! -f /etc/swift/proxy-server.conf.orig ] && cp -v /etc/swift/proxy-server.conf /etc/swift/proxy-server.conf.orig
cat << _EOF_ > /etc/swift/proxy-server.conf
[DEFAULT]
bind_port = 8080
user = swift
swift_dir = /etc/swift

[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server

[app:proxy-server]
use = egg:swift#proxy
account_autocreate = True

[filter:tempauth]
use = egg:swift#tempauth

user_admin_admin = admin .admin .reseller_admin
user_test_tester = testing .admin
user_test2_tester2 = testing2 .admin
user_test_tester3 = testing3
user_test5_tester5 = testing5 service

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:cache]
use = egg:swift#memcache
memcache_servers = $HOSTNAME:11211

[filter:ratelimit]
use = egg:swift#ratelimit

[filter:domain_remap]
use = egg:swift#domain_remap

[filter:catch_errors]
use = egg:swift#catch_errors

[filter:cname_lookup]
use = egg:swift#cname_lookup

[filter:staticweb]
use = egg:swift#staticweb

[filter:tempurl]
use = egg:swift#tempurl

[filter:formpost]
use = egg:swift#formpost

[filter:name_check]
use = egg:swift#name_check

[filter:list-endpoints]
use = egg:swift#list_endpoints

[filter:proxy-logging]
use = egg:swift#proxy_logging

[filter:bulk]
use = egg:swift#bulk

[filter:slo]
use = egg:swift#slo

[filter:dlo]
use = egg:swift#dlo

[filter:container-quotas]
use = egg:swift#container_quotas

[filter:account-quotas]
use = egg:swift#account_quotas

[filter:gatekeeper]
use = egg:swift#gatekeeper

[filter:container_sync]
use = egg:swift#container_sync

[filter:xprofile]
use = egg:swift#xprofile

[filter:versioned_writes]
use = egg:swift#versioned_writes

[filter:copy]
use = egg:swift#copy

[filter:keymaster]
use = egg:swift#keymaster

encryption_root_secret = changeme

[filter:encryption]
use = egg:swift#encryption

[filter:keystoneauth]
use = egg:swift#keystoneauth
operator_roles = admin,user

[filter:authtoken]
paste.filter_factory = keystonemiddleware.auth_token:filter_factory
auth_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:35357
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = swift
password = $PASSWORD
delay_auth_decision = True
_EOF_

blkid /dev/${IDDISK}6 | grep xfs > /dev/null 2>&1 && echo "/dev/${IDDISK}6 already formatted as XFS" || mkfs.xfs -f /dev/${IDDISK}6
blkid /dev/${IDDISK}7 | grep xfs > /dev/null 2>&1 && echo "/dev/${IDDISK}7 already formatted as XFS" || mkfs.xfs -f /dev/${IDDISK}7
blkid /dev/${IDDISK}8 | grep xfs > /dev/null 2>&1 && echo "/dev/${IDDISK}8 already formatted as XFS" || mkfs.xfs -f /dev/${IDDISK}8
blkid /dev/${IDDISK}9 | grep xfs > /dev/null 2>&1 && echo "/dev/${IDDISK}9 already formatted as XFS" || mkfs.xfs -f /dev/${IDDISK}9

mkdir -p /srv/node/${IDDISK}6
mkdir -p /srv/node/${IDDISK}7
mkdir -p /srv/node/${IDDISK}8
mkdir -p /srv/node/${IDDISK}9

grep /dev/${IDDISK}6 /etc/fstab > /dev/null 2>&1 && echo "/dev/${IDDISK}6 already in /etc/fstab" || echo "/dev/${IDDISK}6 /srv/node/${IDDISK}6 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
grep /dev/${IDDISK}7 /etc/fstab > /dev/null 2>&1 && echo "/dev/${IDDISK}7 already in /etc/fstab" || echo "/dev/${IDDISK}7 /srv/node/${IDDISK}7 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
grep /dev/${IDDISK}8 /etc/fstab > /dev/null 2>&1 && echo "/dev/${IDDISK}8 already in /etc/fstab" || echo "/dev/${IDDISK}8 /srv/node/${IDDISK}8 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
grep /dev/${IDDISK}9 /etc/fstab > /dev/null 2>&1 && echo "/dev/${IDDISK}9 already in /etc/fstab" || echo "/dev/${IDDISK}9 /srv/node/${IDDISK}9 xfs noatime,nodiratime,nobarrier,logbufs=8 0 2" >> /etc/fstab
mount /srv/node/${IDDISK}6
mount /srv/node/${IDDISK}7
mount /srv/node/${IDDISK}8
mount /srv/node/${IDDISK}9

[ ! -f /etc/rsyncd.conf.orig ] && cp -v /etc/rsyncd.conf /etc/rsyncd.conf.orig
cat << _EOF_ > /etc/rsyncd.conf
read only = true
use chroot = true
transfer logging = true
log format = %h %o %f %l %b
hosts allow = trusted.hosts
slp refresh = 300
use slp = false

uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $IPMAN

[account]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/account.lock

[container]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/container.lock

[object]
max connections = 2
path = /srv/node/
read only = False
lock file = /var/lock/object.lock
_EOF_

systemctl enable rsyncd.service
systemctl restart rsyncd.service
systemctl status rsyncd.service

echo -n "installing packages... " && zypper -n in --no-recommends openstack-swift-account openstack-swift-container openstack-swift-object python-xml > /dev/null 2>&1 && echo "done"

[ ! -f /etc/swift/account-server.conf.orig ] && cp -v /etc/swift/account-server.conf /etc/swift/account-server.conf.orig
cat << _EOF_ > /etc/swift/account-server.conf
[DEFAULT]
bind_ip = $IPMAN
bind_port = 6002
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon account-server

[app:account-server]
use = egg:swift#account

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[filter:xprofile]
use = egg:swift#xprofile

[account-replicator]

[account-auditor]

[account-reaper]
_EOF_

[ ! -f /etc/swift/container-server.conf.orig ] && cp -v /etc/swift/container-server.conf /etc/swift/container-server.conf.orig
cat << _EOF_ > /etc/swift/container-server.conf
[DEFAULT]
bind_ip = $IPMAN
bind_port = 6001
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon container-server

[app:container-server]
use = egg:swift#container

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[filter:xprofile]
use = egg:swift#xprofile

[container-replicator]

[container-auditor]

[container-updater]
_EOF_

[ ! -f /etc/swift/object-server.conf.orig ] && cp -v /etc/swift/object-server.conf /etc/swift/object-server.conf.orig
cat << _EOF_ > /etc/swift/object-server.conf
[DEFAULT]
bind_ip = $IPMAN
bind_port = 6000
user = swift
swift_dir = /etc/swift
devices = /srv/node
mount_check = True

[pipeline:main]
pipeline = healthcheck recon object-server

[app:object-server]
use = egg:swift#object

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift
recon_lock_path = /var/lock

[filter:xprofile]
use = egg:swift#xprofile

[object-replicator]

[object-auditor]

[object-updater]
_EOF_

chown -R swift:swift /srv/node

STARTDIR=`pwd`
cd /etc/swift
[ -f account.builder ] && echo "account.builder file already exist" || swift-ring-builder account.builder create 10 3 1 
if [ ! -f account.ring.gz ]
  then
    swift-ring-builder account.builder add --region 1 --zone 1 --ip $IPMAN --port 6002 --device ${IDDISK}6 --weight 100
    swift-ring-builder account.builder add --region 1 --zone 1 --ip $IPMAN --port 6002 --device ${IDDISK}7 --weight 100
    swift-ring-builder account.builder add --region 1 --zone 2 --ip $IPMAN --port 6002 --device ${IDDISK}8 --weight 100
    swift-ring-builder account.builder add --region 1 --zone 2 --ip $IPMAN --port 6002 --device ${IDDISK}9 --weight 100
    swift-ring-builder account.builder
    swift-ring-builder account.builder rebalance
  else
    echo "account.ring.gz file already exist"
fi
[ -f container.builder ] && echo "container.builder file already exist" || swift-ring-builder container.builder create 10 3 1 
if [ ! -f container.ring.gz ]
  then
    swift-ring-builder container.builder add --region 1 --zone 1 --ip $IPMAN --port 6001 --device ${IDDISK}6 --weight 100
    swift-ring-builder container.builder add --region 1 --zone 1 --ip $IPMAN --port 6001 --device ${IDDISK}7 --weight 100
    swift-ring-builder container.builder add --region 1 --zone 2 --ip $IPMAN --port 6001 --device ${IDDISK}8 --weight 100
    swift-ring-builder container.builder add --region 1 --zone 2 --ip $IPMAN --port 6001 --device ${IDDISK}9 --weight 100
    swift-ring-builder container.builder
    swift-ring-builder container.builder rebalance
  else
    echo "container.ring.gz file already exist"
fi
[ -f object.builder ] && echo "object.builder file already exist" || swift-ring-builder object.builder create 10 3 1 
if [ ! -f object.ring.gz ]
  then
    swift-ring-builder object.builder add --region 1 --zone 1 --ip $IPMAN --port 6000 --device ${IDDISK}6 --weight 100
    swift-ring-builder object.builder add --region 1 --zone 1 --ip $IPMAN --port 6000 --device ${IDDISK}7 --weight 100
    swift-ring-builder object.builder add --region 1 --zone 2 --ip $IPMAN --port 6000 --device ${IDDISK}8 --weight 100
    swift-ring-builder object.builder add --region 1 --zone 2 --ip $IPMAN --port 6000 --device ${IDDISK}9 --weight 100
    swift-ring-builder object.builder
    swift-ring-builder object.builder rebalance
  else
    echo "object.ring.gz file already exist"
fi
cd $STARTDIR

[ ! -f /etc/swift/swift.conf.orig ] && cp -v /etc/swift/swift.conf /etc/swift/swift.conf.orig
cat << _EOF_ > /etc/swift/swift.conf
[swift-hash]
swift_hash_path_suffix = openSUSE
swift_hash_path_prefix = GLiB

[storage-policy:0]
name = Policy-0
default = yes
aliases = yellow, orange
_EOF_

chown -R root:swift /etc/swift

systemctl enable openstack-swift-proxy.service memcached.service openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
systemctl restart openstack-swift-proxy.service memcached.service openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service
systemctl status openstack-swift-proxy.service memcached.service openstack-swift-account.service openstack-swift-account-auditor.service openstack-swift-account-reaper.service openstack-swift-account-replicator.service openstack-swift-container.service openstack-swift-container-auditor.service openstack-swift-container-replicator.service openstack-swift-container-updater.service openstack-swift-object.service openstack-swift-object-auditor.service openstack-swift-object-replicator.service openstack-swift-object-updater.service

swift stat
