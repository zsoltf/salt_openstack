{% set rabbit_pass = salt['pillar.get']('openstack:passwords:rabbit_pass') %}
{% set cinder_host = grains['id'] %}
{% set cinder_pass = salt['pillar.get']('openstack:passwords:cinder_pass') %}
#HACK
{% set database = "mysql-s3" %}
{% set cinder_db_pass = salt['pillar.get']('openstack:passwords:cinder_db_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') | dictsort() | first %}

{% set admin_network = salt['pillar.get']('openstack:admin_network') %}
{% set ips = salt['network.ip_addrs']() %}
{% set storage_ip = [] %}
{% for ip in ips if salt['network.ip_in_subnet'](ip, admin_network) %}
  {% do storage_ip.append(ip) %}
{% endfor %}
{% set storage_ip = storage_ip|first %}

openstack-cinder-db:

  mysql_database.present:
    - name: cinder

  mysql_user.present:
    - name: cinder
    - password: {{ cinder_db_pass }}
    - host: '%'

  mysql_grants.present:
    - user: cinder
    - grant: all privileges
    - database: cinder.*
    - host: '%'
    - require:
        - mysql_database: openstack-cinder-db
        - mysql_user: openstack-cinder-db

openstack-cinder:
  pkg.installed:
    - names:
        - cinder-api
        - cinder-scheduler

openstack-cinder-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/cinder/cinder.conf
        sed -i /^$/d /etc/cinder/cinder.conf
    - onchanges:
      - pkg: openstack-cinder

openstack-cinder-initial-config:
  ini.options_present:
    - name: /etc/cinder/cinder.conf
    - sections:
        database:
          connection: 'mysql+pymysql://cinder:{{ cinder_db_pass }}@{{ database }}/cinder'
        DEFAULT:
          auth_strategy: keystone
          transport_url: rabbit://openstack:{{ rabbit_pass }}@{{ controller }}:5672/
          my_ip: {{ storage_ip }}
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ controller }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: cinder
          password: {{ cinder_pass }}
        oslo_concurrency:
          lock_path: /var/lib/cinder/tmp

openstack-cinder-nova-config-controller:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        cinder:
          os_region_name: RegionOne

# TODO: use native salt states
openstack-cinder-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $cinder_pass cinder
        openstack role add --project service --user cinder admin
        openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
        openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
        openstack endpoint create --region RegionOne volumev2 public http://{{ controller }}:8776/v2/%\(project_id\)s
        openstack endpoint create --region RegionOne volumev2 internal http://{{ controller }}:8776/v2/%\(project_id\)s
        openstack endpoint create --region RegionOne volumev2 admin http://{{ controller }}:8776/v2/%\(project_id\)s
        openstack endpoint create --region RegionOne volumev3 public http://{{ controller }}:8776/v3/%\(project_id\)s
        openstack endpoint create --region RegionOne volumev3 internal http://{{ controller }}:8776/v3/%\(project_id\)s
        openstack endpoint create --region RegionOne volumev3 admin http://{{ controller }}:8776/v3/%\(project_id\)s
    - unless: openstack user show cinder
    - env:
        cinder_pass: {{ cinder_pass }}
        OS_CLOUD: test

openstack-cinder-bootstrap-db:
  cmd.run:
    - name: |
        cinder-manage db sync && \
        service nova-api restart && \
        service cinder-scheduler restart && \
        service apache2 restart
    - onchanges:
        - ini: openstack-cinder-initial-config
        - cmd: openstack-cinder-bootstrap
