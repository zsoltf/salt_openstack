{% set keystone_db_pass = salt['pillar.get']('openstack:passwords:keystone_db_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'ip', 'grain') | dictsort() | first %}

openstack-keystone-db:

  mysql_database.present:
    - name: keystone

  mysql_user.present:
    - name: keystone
    - password: {{ keystone_db_pass }}
    - host: '%'

  mysql_grants.present:
    - user: keystone
    - grant: all privileges
    - database: keystone.*
    - host: '%'
    - require:
        - mysql_database: openstack-keystone-db
        - mysql_user: openstack-keystone-db

openstack-keystone:
  pkg.installed:
    - name: keystone

openstack-keystone-config:
  openstack_config.present:
    - name: connection
    - value: mysql+pymysql://keystone:{{ keystone_db_pass }}@{{ controller }}/keystone
    - filename: /etc/keystone/keystone.conf
    - section: database
