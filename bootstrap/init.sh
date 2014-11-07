#!/bin/bash

uid=""
gid=""
password=""

while [[ $# > 1 ]]
do
    key="$1"
    shift

    case $key in
    --uid)
        uid=$1
        shift
        ;;
    --gid)
        gid=$1
        shift
        ;;
    --password)
        password=$1
        shift
        ;;
    esac
done

[ -z "$uid" ] || usermod --uid=$uid jenkins
[ -z "$gid" ] || usermod --gid=$gid jenkins
[ -z "$password" ] || echo "jenkins:$password" | chpasswd

chown -R jenkins:jenkins /home/jenkins

sudo -i mysqld --datadir=/var/lib/mysql --user=mysql --init-file='/tmp/mysql-first-time.sql' &
/usr/sbin/sshd -D
