{% set placement_host = grains['id'] %}
{% set placement_pass = salt['pillar.get']('openstack:passwords:placement_pass') %}
{% set placement_db_pass = salt['pillar.get']('openstack:passwords:placement_db_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'ip', 'grain') | dictsort() | first %}

openstack-placement-db:

  mysql_database.present:
    - name: placement

  mysql_user.present:
    - name: placement
    - password: {{ placement_db_pass }}
    - host: '%'

  mysql_grants.present:
    - user: placement
    - grant: all privileges
    - database: placement.*
    - host: '%'
    - require:
        - mysql_database: openstack-placement-db
        - mysql_user: openstack-placement-db

openstack-placement:
  pkg.installed:
    - name: placement-api

openstack-placement-initial-config:
  ini.options_present:
    - name: /etc/placement/placement.conf
    - sections:
        api:
          auth_strategy: keystone
        placement_database:
          connection: 'mysql+pymysql://placement:{{ placement_db_pass }}@{{ controller }}/placement'
        keystone_authtoken:
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ controller }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: placement
          password: {{ placement_pass }}

openstack-placement-bootstrap-db:
  cmd.run:
    - name: |
        placement-manage db sync && \
        service apache2 restart
    - onchanges:
        - ini: openstack-placement-initial-config

# TODO: use native salt state
openstack-placement-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $placement_pass placement
        openstack role add --project service --user placement admin
        openstack service create --name placement --description "Placement API" placement
        openstack endpoint create --region RegionOne placement public http://{{ controller }}:8778
        openstack endpoint create --region RegionOne placement internal http://{{ controller }}:8778
        openstack endpoint create --region RegionOne placement admin http://{{ controller }}:8778
    - unless: openstack user show placement
    - env:
        placement_pass: {{ placement_pass }}
        OS_CLOUD: test
