{% from 'openstack/map.jinja' import database, mq, memcache, controller, controller_ip, passwords with context %}
{% set nova_host = grains['id'] %}

openstack-nova:
  pkg.installed:
    - pkgs:
      - nova-api
      - nova-conductor
      - nova-novncproxy
      - nova-scheduler

openstack-nova-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/nova/nova.conf
        sed -i /^$/d /etc/nova/nova.conf
    - onchanges:
      - pkg: openstack-nova

openstack-nova-initial-config:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        api:
          auth_strategy: keystone
        api_database:
          connection: 'mysql+pymysql://nova:{{ passwords.nova_db_pass }}@{{ database }}/nova_api'
        database:
          connection: 'mysql+pymysql://nova:{{ passwords.nova_db_pass }}@{{ database }}/nova'
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          my_ip: {{ controller_ip }}
          use_neutron: 'true'
          firewall_driver: 'nova.virt.firewall.NoopFirewallDriver'
          log_dir: ''
        glance:
          api_servers: http://{{ controller }}:9292
        oslo_concurrency:
          lock_path: /var/lib/nova/tmp
        placement:
          region_name: RegionOne
          project_domain_name: Default
          project_name: service
          auth_type: password
          user_domain_name: Default
          auth_url: http://{{ controller }}:5000/v3
          username: placement
          password: {{ passwords.placement_pass }}
        scheduler:
          discover_hosts_in_cells_interval: 300
        keystone_authtoken:
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: nova
          password: {{ passwords.nova_pass }}
        vnc:
          enabled: 'true'
          server_list: '$my_ip'
          server_proxyclient_address: '$my_ip'

# TODO: use native salt state
openstack-nova-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $nova_pass nova && \
        openstack role add --project service --user nova admin && \
        openstack service create --name nova --description "OpenStack Compute" compute && \
        openstack endpoint create --region RegionOne compute public http://{{ controller }}:8774/v2.1 && \
        openstack endpoint create --region RegionOne compute internal http://{{ controller }}:8774/v2.1 && \
        openstack endpoint create --region RegionOne compute admin http://{{ controller }}:8774/v2.1
    - unless: openstack user show nova
    - env:
        nova_pass: {{ passwords.nova_pass }}
        OS_CLOUD: test

openstack-nova-bootstrap-db:
  cmd.run:
    - name: |
        nova-manage api_db sync && \
        nova-manage cell_v2 map_cell0 && \
        nova-manage cell_v2 create_cell --name=cell1 --verbose && \
        nova-manage db sync && \
        nova-manage cell_v2 list_cells && \
        service nova-api restart && \
        service nova-scheduler restart && \
        service nova-conductor restart && \
        service nova-novncproxy restart
    - onchanges:
        - ini: openstack-nova-initial-config

