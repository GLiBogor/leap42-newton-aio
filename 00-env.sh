#!/bin/bash

source os.conf


##### NTP Service #####
[ ! -f /etc/ntp.conf.orig ] && cp -v /etc/ntp.conf /etc/ntp.conf.orig
grep opensuse.pool.ntp.org /etc/ntp.conf > /dev/null 2>&1
if [ $? -ne 0 ]
  then
    echo "server 0.opensuse.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 1.opensuse.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 2.opensuse.pool.ntp.org iburst" >> /etc/ntp.conf
    echo "server 3.opensuse.pool.ntp.org iburst" >> /etc/ntp.conf
    systemctl enable ntpd.service
    systemctl restart ntpd.service
    systemctl status ntpd.service
fi
ntpq -p


##### Repositories #####
[ ! -f /etc/zypp/repos.d/Newton.repo ] && zypper ar -f obs://Cloud:OpenStack:Newton/openSUSE_Leap_42.2 Newton
zypper --gpg-auto-import-keys ref && zypper -n up --skip-interactive
zypper -n in --no-recommends python-openstackclient


##### MariaDB Database Service #####
zypper -n in --no-recommends mariadb-client mariadb python-PyMySQL
if [ ! -f /etc/my.cnf.d/openstack.cnf ]
  then
cat << _EOF_ > /etc/my.cnf.d/openstack.cnf
[mysqld]
bind-address = $IPMAN
default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
_EOF_
    systemctl enable mysql.service
    systemctl restart mysql.service
    systemctl status mysql.service
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('$PASSWORD') WHERE User='root';"
    mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -e "DELETE FROM mysql.user WHERE User='';"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';"
    mysql -e "FLUSH PRIVILEGES;"
fi


##### RabbitMQ Service #####
zypper -n in --no-recommends erlang-epmd rabbitmq-server
[ ! -f /usr/lib/systemd/system/epmd.socket.orig ] && cp -v /usr/lib/systemd/system/epmd.socket /usr/lib/systemd/system/epmd.socket.orig
sed -i 's/ListenStream=127.0.0.1:4369/ListenStream=0.0.0.0:4369/g' /usr/lib/systemd/system/epmd.socket
systemctl daemon-reload
systemctl restart epmd.socket epmd.service
systemctl status epmd.socket epmd.service
systemctl enable rabbitmq-server.service
systemctl restart rabbitmq-server.service
systemctl status rabbitmq-server.service
sleep 10
rabbitmqctl add_user openstack $PASSWORD
rabbitmqctl set_permissions openstack ".*" ".*" ".*"


##### Memcached Service #####
zypper -n in --no-recommends memcached python-python-memcached
systemctl enable memcached.service
systemctl restart memcached.service
systemctl status memcached.service
