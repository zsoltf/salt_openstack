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
        controller_worker:
          amp_image_owner_id: '61c918a667c24912bce8024f3e9e4e96'
          amp_image_tag: amphora
          amp_ssh_key_name: amphora_key
          amp_secgroup_list: '4307de04-74b9-4449-a128-8d74e280504f'
          amp_boot_network_list: '528deb15-daa7-43cf-8e37-0a12ac8140ff'
          amp_flavor_id: 200
          network_driver: allowed_address_pairs_driver
          compute_driver: compute_nova_driver
          amphora_driver: amphora_haproxy_rest_driver
          client_ca: /etc/octavia/certs/client_ca.cert.pem


openstack-octavia-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $octavia_pass octavia
        openstack role add --project service --user octavia admin
        openstack service create --name octavia --description "OpenStack Octavia" load-balancer
        openstack endpoint create --region RegionOne load-balancer public http://{{ controller }}:9876
        openstack endpoint create --region RegionOne load-balancer internal http://{{ controller }}:9876
        openstack endpoint create --region RegionOne load-balancer admin http://{{ controller }}:9876

        # needs to be done with the octavia user
        #openstack security group create lb-mgmt-sec-grp
        #openstack security group rule create --protocol icmp lb-mgmt-sec-grp
        #openstack security group rule create --protocol tcp --dst-port 22 lb-mgmt-sec-grp
        #openstack security group rule create --protocol tcp --dst-port 9443 lb-mgmt-sec-grp
        #openstack security group create lb-health-mgr-sec-grp
        #openstack security group rule create --protocol udp --dst-port 5555 lb-health-mgr-sec-grp

        #openstack keypair create --public-key ~/.ssh/id_rsa.pub amphora_key

    - unless: openstack user show octavia
    - env:
        octavia_pass: {{ passwords.octavia_pass }}
        OS_CLOUD: test

openstack-octavia-bootstrap-db:
  cmd.run:
    - name: |
        octavia-db-manage --config-file /etc/octavia/octavia.conf upgrade head
        systemctl restart octavia-api octavia-health-manager octavia-housekeeping octavia-worker
    - onchanges:
        - ini: openstack-octavia-initial-config
        - cmd: openstack-octavia-bootstrap


#TODO: horizon dashboards are bad, they should go somewhere else
openstack-octavia-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q octavia-dashboard
        cp /usr/local/lib/python3.6/dist-packages/octavia_dashboard/enabled/_1*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-octavia-bootstrap-db
