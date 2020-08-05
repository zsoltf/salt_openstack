#!/usr/bin/env bash

# cat salt-master.sh | ssh root@myhost 'bash -s'

SALT=mimas
DC=home

wget -O - https://repo.saltstack.com/py3/ubuntu/18.04/amd64/2019.2/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
echo 'deb http://repo.saltstack.com/py3/ubuntu/18.04/amd64/2019.2 bionic main' > /etc/apt/sources.list.d/saltstack.list
apt update
apt install -y salt-master
systemctl enable salt-master
systemctl restart salt-master
