#!/usr/bin/env bash

# cat salt2019.sh | ssh root@myhost 'bash -s'

SALT=catboat
DC=boneyard

wget -O - https://repo.saltstack.com/py3/ubuntu/18.04/amd64/2019.2/SALTSTACK-GPG-KEY.pub | sudo apt-key add -
echo 'deb http://repo.saltstack.com/py3/ubuntu/18.04/amd64/2019.2 bionic main' > /etc/apt/sources.list.d/saltstack.list
mkdir -p /etc/salt/minion.d
echo -e "master: ${SALT}\nlog_level: info" >> /etc/salt/minion.d/minion.conf
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
apt update
apt install -y salt-minion
salt-call test.ping
salt-call grains.set datacenter $DC
