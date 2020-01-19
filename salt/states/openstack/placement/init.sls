{% from 'openstack/map.jinja' import memcache, database, controller, passwords with context %}
{% set placement_host = grains['id'] %}

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
          connection: 'mysql+pymysql://placement:{{ passwords.placement_db_pass }}@{{ database }}/placement'
        keystone_authtoken:
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: placement
          password: {{ passwords.placement_pass }}

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
        placement_pass: {{ passwords.placement_pass }}
        OS_CLOUD: test

