{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-octavia:
  pkg.installed:
    - names:
        - octavia-api
        - octavia-health-manager
        - octavia-housekeeping
        - octavia-worker
        - python3-octavia
        - python3-octaviaclient

openstack-octavia-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/octavia/octavia.conf
        sed -i /^$/d /etc/octavia/octavia.conf
    - onchanges:
      - pkg: openstack-octavia

openstack-octavia-initial-config:
  ini.options_present:
    - name: /etc/octavia/octavia.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        database:
          connection: 'mysql+pymysql://octavia:{{ passwords.octavia_db_pass }}@{{ database }}/octavia'
        oslo_messaging:
          topic: octavia_prov
        api_settings:
          bind_host: 0.0.0.0
          bind_port: 9876
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: octavia
          password: {{ passwords.octavia_pass }}
        service_auth:
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ controller }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: octavia
          password: {{ passwords.octavia_pass }}
        certificates:
          server_certs_key_passphrase: insecure-key-do-not-use-this-key
          ca_private_key_passphrase: not-secure-passphrase
          ca_private_key: /etc/octavia/certs/private/server_ca.key.pem
          ca_certificate: /etc/octavia/certs/server_ca.cert.pem
        haproxy_amphora:
          server_ca: /etc/octavia/certs/server_ca-chain.cert.pem
          client_cert: /etc/octavia/certs/private/client.cert-and-key.pem
        health_manager:
          bind_port: 5555
          bind_ip: 172.16.0.2
          controller_ip_port_list: 172.16.0.2:5555
        #TODO:
        controller_worker:
          # id of service project
          amp_image_owner_id: 'd62005002dbf4ce0b0c2d7146e76f7bb'
          amp_image_tag: amphora
          amp_ssh_key_name: amphora_key
          # lb-mgmt-sec-grp-id
          amp_secgroup_list: 'd1fc4957-1809-4bb2-94f3-95345b2fdec4'
          # lb-mgmt-net-id
          amp_boot_network_list: 'c4e5acd3-ab3f-4d2d-8301-9559430384ec'
          amp_flavor_id: 200
          network_driver: allowed_address_pairs_driver
          compute_driver: compute_nova_driver
          amphora_driver: amphora_haproxy_rest_driver
          client_ca: /etc/octavia/certs/client_ca.cert.pem


# for manual debugging
opensatck-octavia-admin-openrc:
  file.managed:
    - name: /root/octavia_openrc
    - contents: |
        export OS_PROJECT_DOMAIN_NAME=Default
        export OS_USER_DOMAIN_NAME=Default
        export OS_PROJECT_NAME=service
        export OS_USERNAME=octavia
        export OS_PASSWORD={{ passwords.octavia_pass }}
        export OS_AUTH_URL=http://{{ controller }}:5000
        export OS_IDENTITY_API_VERSION=3
        export OS_IMAGE_API_VERSION=2
        export OS_VOLUME_API_VERSION=3

opensatck-octavia-dhclient:
  file.managed:
    - name: /etc/dhcp/octavia/dhclient.conf
    - makedirs: True
    - mode: 644
    - dir_mode: 755
    - contents: |
        request subnet-mask,broadcast-address,interface-mtu;
        do-forward-updates false;

openstack-octavia-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $octavia_pass octavia
        openstack role add --project service --user octavia admin
        openstack service create --name octavia --description "OpenStack Octavia" load-balancer
        openstack endpoint create --region RegionOne load-balancer public http://{{ controller }}:9876
        openstack endpoint create --region RegionOne load-balancer internal http://{{ controller }}:9876
        openstack endpoint create --region RegionOne load-balancer admin http://{{ controller }}:9876
    - unless: openstack user show octavia
    - env:
        octavia_pass: {{ passwords.octavia_pass }}
        OS_CLOUD: test

openstack-octavia-do-things:
  cmd.run:
    - name: |
        openstack security group create lb-mgmt-sec-grp
        openstack security group rule create --protocol icmp lb-mgmt-sec-grp
        openstack security group rule create --protocol tcp --dst-port 22 lb-mgmt-sec-grp
        openstack security group rule create --protocol tcp --dst-port 9443 lb-mgmt-sec-grp
        openstack security group create lb-health-mgr-sec-grp
        openstack security group rule create --protocol udp --dst-port 5555 lb-health-mgr-sec-grp
        openstack keypair create --public-key ~/.ssh/id_rsa.pub amphora_key
    - env:
        OS_PROJECT_DOMAIN_NAME: Default
        OS_USER_DOMAIN_NAME: Default
        OS_PROJECT_NAME: service
        OS_USERNAME: octavia
        OS_PASSWORD: {{ passwords.octavia_pass }}
        OS_AUTH_URL: http://{{ controller }}:5000
        OS_IDENTITY_API_VERSION: 3
        OS_IMAGE_API_VERSION: 2
        OS_VOLUME_API_VERSION: 3
    - onchanges:
      - cmd: openstack-octavia-bootstrap


#TODO: dogtag or https://docs.openstack.org/octavia/latest/admin/guides/certificates.html
#NOTE: this should not be used for normal deployments... it's just to get me over the hump
openstack-octavia-certs:
  cmd.run:
    - name: |
        git clone https://opendev.org/openstack/octavia.git
        cd octavia/bin/
        source create_dual_intermediate_CA.sh
        mkdir -p /etc/octavia/certs/private
        chmod 755 /etc/octavia -R
        cp -p etc/octavia/certs/server_ca.cert.pem /etc/octavia/certs
        cp -p etc/octavia/certs/server_ca-chain.cert.pem /etc/octavia/certs
        cp -p etc/octavia/certs/server_ca.key.pem /etc/octavia/certs/private
        cp -p etc/octavia/certs/client_ca.cert.pem /etc/octavia/certs
        cp -p etc/octavia/certs/client.cert-and-key.pem /etc/octavia/certs/private
        chmod 440 /etc/octavia/certs/server_ca.cert.pem
        chmod 440 /etc/octavia/certs/private/server_ca.key.pem
        chgrp octavia /etc/octavia/certs/server_ca.cert.pem
        chgrp octavia /etc/octavia/certs/private/server_ca.key.pem
    - onchanges:
      - cmd: openstack-octavia-bootstrap

openstack-octavia-build-image:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        apt-get -qq install -y qemu-utils git kpartx debootstrap
        git clone https://opendev.org/openstack/octavia.git
        cd octavia/diskimage-create
        pip3 install -r requirements.txt
        ./diskimage-create.sh
    - creates: /root/octavia/diskimage-create/amphora-x64-haproxy.qcow2

openstack-octavia-upload-image:
  cmd.run:
    - name: |
        openstack image create --disk-format qcow2 \
          --container-format bare --private --tag amphora \
          --file /root/octavia/diskimage-create/amphora-x64-haproxy.qcow2 amphora-x64-haproxy
        openstack flavor create --id 200 --vcpus 1 --ram 1024 \
          --disk 2 "amphora" --private
    - env:
        OS_PROJECT_DOMAIN_NAME: Default
        OS_USER_DOMAIN_NAME: Default
        OS_PROJECT_NAME: service
        OS_USERNAME: octavia
        OS_PASSWORD: {{ passwords.octavia_pass }}
        OS_AUTH_URL: http://{{ controller }}:5000
        OS_IDENTITY_API_VERSION: 3
        OS_IMAGE_API_VERSION: 2
        OS_VOLUME_API_VERSION: 3
    - onchanges:
      - cmd: openstack-octavia-build-image


openstack-octavia-network-there-has-to-be-a-better-way:
  test.nop:
    - name: |

        openstack network create lb-mgmt-net
        openstack subnet create --subnet-range $OCTAVIA_MGMT_SUBNET --allocation-pool \
        start=$OCTAVIA_MGMT_SUBNET_START,end=$OCTAVIA_MGMT_SUBNET_END \
        --network lb-mgmt-net lb-mgmt-subnet

        SUBNET_ID=$(openstack subnet show lb-mgmt-subnet -f value -c id)
        PORT_FIXED_IP="--fixed-ip subnet=$SUBNET_ID,ip-address=$OCTAVIA_MGMT_PORT_IP"

        MGMT_PORT_ID=$(openstack port create --security-group \
        lb-health-mgr-sec-grp --device-owner Octavia:health-mgr \
        --host=$(hostname) -c id -f value --network lb-mgmt-net \
        $PORT_FIXED_IP octavia-health-manager-listen-port)

        MGMT_PORT_MAC=$(openstack port show -c mac_address -f value \
        $MGMT_PORT_ID)

        MGMT_PORT_IP=$(openstack port show -f yaml -c fixed_ips \
        $MGMT_PORT_ID | awk '{FS=",|";gsub(",","");gsub("'\''",""); \
        for(line = 1; line <= NF; ++line) {if ($line ~ /^- ip_address:/) \
        {split($line, word, " ");if (ENVIRON["IPV6_ENABLED"] == "" && word[3] ~ /\./) \
        print word[3];if (ENVIRON["IPV6_ENABLED"] != "" && word[3] ~ /:/) print word[3];} \
        else {split($line, word, " ");for(ind in word) {if (word[ind] ~ /^ip_address=/) \
        {split(word[ind], token, "=");if (ENVIRON["IPV6_ENABLED"] == "" && token[2] ~ /\./) \
        print token[2];if (ENVIRON["IPV6_ENABLED"] != "" && token[2] ~ /:/) print token[2];}}}}}')

        sudo ip link add o-hm0 type veth peer name o-bhm0
        NETID=$(openstack network show lb-mgmt-net -c id -f value)
        BRNAME=brq$(echo $NETID|cut -c 1-11)
        sudo brctl addif $BRNAME o-bhm0
        sudo ip link set o-bhm0 up

        sudo ip link set dev o-hm0 address $MGMT_PORT_MAC
        sudo iptables -I INPUT -i o-hm0 -p udp --dport 5555 -j ACCEPT
        sudo dhclient -v o-hm0 -cf /etc/dhcp/octavia

    - env:
        OCTAVIA_MGMT_SUBNET: 172.16.0.0/12
        OCTAVIA_MGMT_SUBNET_START: 172.16.0.100
        OCTAVIA_MGMT_SUBNET_END: 172.16.31.254
        OCTAVIA_MGMT_PORT_IP: 172.16.0.2

openstack-octavia-network-beast-1:
  ini.options_present:
    - name: /etc/systemd/network/o-hm0.network
    - sections:
        Match:
          name: o-hm0
        Network:
          DHCP: 'yes'

openstack-octavia-network-beast-2:
  ini.options_present:
    - name: /etc/systemd/system/octavia-interface.service
    - sections:
        Unit:
          Description: Octavia Interface Creator
          Requires: neutron-linuxbridge-agent.service
          After: neutron-linuxbridge-agent.service
        Service:
          Type: oneshot
          RemainAfterExit: 'true'
          ExecStart: /opt/octavia-interface.sh start
          ExecStop: /opt/octavia-interface.sh stop
        Install:
          WantedBy: multi-user.target

openstack-octavia-network-beast-3:
  file.managed:
    - name: /opt/octavia-interface.sh
    - contents: |
        #!/bin/bash

        set -ex

        # TODO: replace with actual values
        MAC=$MGMT_PORT_MAC
        BRNAME=$BRNAME

        if [ "$1" == "start" ]; then
          ip link add o-hm0 type veth peer name o-bhm0
          brctl addif $BRNAME o-bhm0
          ip link set o-bhm0 up
          ip link set dev o-hm0 address $MAC
          ip link set o-hm0 up
          iptables -I INPUT -i o-hm0 -p udp --dport 5555 -j ACCEPT
        elif [ "$1" == "stop" ]; then
          ip link del o-hm0
        else
          brctl show $BRNAME
          ip a s dev o-hm0
        fi


# need BRNAME and MGMT_PORT_MAC for bridge interface script
# need amp_image_owner_id, amp_secgroup_list, amp_boot_network_list:
# update controller_worker section of /etc/octavia/octavia.conf with actual ids
# need 3 systemd files to keep the network beast afloat
# https://docs.openstack.org/octavia/latest/install/install-ubuntu.html

#openstack-octavia-bootstrap-db:
#  cmd.run:
#    - name: |
#        octavia-db-manage --config-file /etc/octavia/octavia.conf upgrade head
#        systemctl restart octavia-api octavia-health-manager octavia-housekeeping octavia-worker
#    - onchanges:
#        - ini: openstack-octavia-initial-config
#        - cmd: openstack-octavia-bootstrap


##TODO: horizon dashboards are bad, they should go somewhere else
#openstack-octavia-dashboard:
#  cmd.run:
#    - name: |
#        apt-get -qq install -y python3-pip
#        pip3 install -q octavia-dashboard
#        cp /usr/local/lib/python3.6/dist-packages/octavia_dashboard/enabled/_1*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
#        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
#        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
#        service apache2 restart
#    - onchanges:
#      - cmd: openstack-octavia-bootstrap-db
