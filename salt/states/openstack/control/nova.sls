{% set nova_host = grains['id'] %}
{% set placement_pass = salt['pillar.get']('openstack:passwords:placement_pass') %}
{% set rabbit_pass = salt['pillar.get']('openstack:passwords:rabbit_pass') %}
{% set nova_pass = salt['pillar.get']('openstack:passwords:nova_pass') %}
{% set nova_db_pass = salt['pillar.get']('openstack:passwords:nova_db_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'ip', 'grain') | dictsort() | first %}
{% set internal_network = salt['pillar.get']('openstack:internal_network') %}

{% set controller_ip = [] %}
{% for ip in ips if salt['network.ip_in_subnet'](ip, internal_network) %}
  {% do controller_ip.append(ip) %}
{% endfor %}
{% set controller_ip = controller_ip|first %}

openstack-nova-db:
  mysql_database.present:
    - name: nova
  mysql_user.present:
    - name: nova
    - password: {{ nova_db_pass }}
    - host: '%'
  mysql_grants.present:
    - user: nova
    - grant: all privileges
    - database: nova.*
    - host: '%'
    - require:
        - mysql_database: openstack-nova-db
        - mysql_user: openstack-nova-db

openstack-nova_api-db:
  mysql_database.present:
    - name: nova_api
  mysql_user.present:
    - name: nova
    - password: {{ nova_db_pass }}
    - host: '%'
  mysql_grants.present:
    - user: nova
    - grant: all privileges
    - database: nova_api.*
    - host: '%'
    - require:
        - mysql_database: openstack-nova_api-db
        - mysql_user: openstack-nova_api-db

openstack-nova_cell0-db:
  mysql_database.present:
    - name: nova_cell0
  mysql_user.present:
    - name: nova
    - password: {{ nova_db_pass }}
    - host: '%'
  mysql_grants.present:
    - user: nova
    - grant: all privileges
    - database: nova_cell0.*
    - host: '%'
    - require:
        - mysql_database: openstack-nova_cell0-db
        - mysql_user: openstack-nova_cell0-db


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
          connection: 'mysql+pymysql://nova:{{ nova_db_pass }}@{{ controller }}/nova_api'
        database:
          connection: 'mysql+pymysql://nova:{{ nova_db_pass }}@{{ controller }}/nova'
        DEFAULT:
          transport_url: rabbit://openstack:{{ rabbit_pass }}@{{ controller }}:5672/
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
          password: {{ placement_pass }}
        keystone_authtoken:
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ controller }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: nova
          password: {{ nova_pass }}
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
        nova_pass: {{ nova_pass }}
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
