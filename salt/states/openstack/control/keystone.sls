{% set admin_pass = salt['pillar.get']('openstack:passwords:admin_pass') %}
{% set keystone_host = grains['id'] %}
#HACK
{% set database = "mysql-s3" %}
{% set keystone_db_pass = salt['pillar.get']('openstack:passwords:keystone_db_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') | dictsort() | first %}

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

openstack-keystone-initial-config:
  ini.options_present:
    - name: /etc/keystone/keystone.conf
    - sections:
        database:
          connection: 'mysql+pymysql://keystone:{{ keystone_db_pass }}@{{ database }}/keystone'
        token:
          provider: fernet

openstack-keystone-bootstrap-identity-service:
  cmd.run:
    - name: |
        keystone-manage db_sync && \
        keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone && \
        keystone-manage credential_setup --keystone-user keystone --keystone-group keystone && \
        keystone-manage bootstrap --bootstrap-password $admin_pass \
          --bootstrap-admin-url http://{{ keystone_host }}:5000/v3/ \
          --bootstrap-internal-url http://{{ keystone_host }}:5000/v3/ \
          --bootstrap-public-url http://{{ keystone_host }}:5000/v3/ \
          --bootstrap-region-id RegionOne
    - env: {{ salt['pillar.get']('openstack:passwords') }}
    - onchanges:
        - ini: openstack-keystone-initial-config

openstack-keystone-apache-config:
  file.replace:
    - name: /etc/apache2/apache2.conf
    - append_if_not_found: True
    - backup: True
    - pattern: ^ServerName .*
    - repl: ServerName {{ keystone_host }}

openstack-keystone-apache-service:
  service.running:
    - name: apache2
    - enable: True
    - watch:
      - file: openstack-keystone-apache-config

# admin auth
openstack-admin-user-clouds-yaml:
  file.managed:
    - name: /etc/openstack/clouds.yaml
    - makedirs: True
    - contents: |
        clouds:
          test:
            auth:
              username: 'admin'
              password: {{ admin_pass }}
              project_name: 'admin'
              auth_url: 'http://{{ controller }}:5000/v3'
              user_domain_name: Default
              project_domain_name: Default
            region_name: RegionOne
    - require:
      - service: openstack-keystone-apache-service

# project for openstack services
openstack-keystone-service-project:
  cmd.run:
    - name: |
        openstack project create --domain default --description "Service Project" service
    - unless: openstack project show service
    - env:
        OS_CLOUD: test
    - require:
      - file: openstack-admin-user-clouds-yaml

# example project, user and role
# TODO: use native salt states
openstack-keystone-example-users:
  cmd.run:
    - name: |
        openstack project create --domain default --description "Demo Project" myproject && \
        openstack user create --domain default --password $user_pass myuser && \
        openstack role create myrole && \
        openstack role add --project myproject --user myuser myrole
    - unless: openstack project show myproject
    - env:
        user_pass: mypass
        OS_CLOUD: test
    - require:
      - file: openstack-admin-user-clouds-yaml
