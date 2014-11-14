#!/bin/bash

[ -z "$jenkins_uid" ] || usermod --uid=$jenkins_uid jenkins
[ -z "$jenkins_gid" ] || usermod --gid=$jenkins_gid jenkins
[ -z "$jenkins_password" ] || echo "jenkins:$jenkins_password" | chpasswd

chown -R jenkins:jenkins /home/jenkins

sudo -i /usr/local/mysql/bin/mysqld --datadir=/var/lib/mysql --user=mysql --init-file='/tmp/mysql-first-time.sql' &
disown
exec "$@"
