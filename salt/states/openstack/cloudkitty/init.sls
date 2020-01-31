{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

# not ready yet... sad kitty

openstack-cloudkitty:
  pkg.installed:
    - names:
        - cloudkitty-api
        - cloudkitty-processor

openstack-cloudkitty-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/cloudkitty/cloudkitty.conf
        sed -i /^$/d /etc/cloudkitty/cloudkitty.conf
    - onchanges:
      - pkg: openstack-cloudkitty

openstack-cloudkitty-initial-config:
  ini.options_present:
    - name: /etc/cloudkitty/cloudkitty.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          verbose: 'true'
          debug: 'false'
          log_dir: /var/log/cloudkitty
          auth_strategy: keystone
        database:
          connection: 'mysql+pymysql://cloudkitty:{{ passwords.cloudkitty_db_pass }}@{{ database }}/cloudkitty'
        ks_auth:
          auth_type: v3password
          auth_protocol: http
          auth_url: http://{{ controller }}:5000
          indentity_uri: http://{{ controller }}:5000
          username: cloudkitty
          password: {{ passwords.cloudkitty_pass }}
          project_name: service
          user_domain_name: Default
          project_domain_name: Default
        keystone_authtoken:
          auth_section: ks_auth
        storage:
          version: 2
          backend: pymysql
        storage_elasticsearch:
          host: http://{{ controller }}:9200
        fetcher:
          backend: gnocchi
        fetcher_gnocchi:
          auth_section: ks_auth
          region_name: RegionOne
        collect:
          collector: gnocchi
        collector_gnocchi:
          auth_section: ks_auth
          region_name: RegionOne

openstack-cloudkitty-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $cloudkitty_pass cloudkitty
        openstack role add --project service --user cloudkitty admin
        openstack service create rating --name cloudkitty --description "OpenStack Rating Service"
        openstack endpoint create rating --region RegionOne public http://{{ controller }}:8889
        openstack endpoint create rating --region RegionOne admin http://{{ controller }}:8889
        openstack endpoint create rating --region RegionOne internal http://{{ controller }}:8889
    - unless: openstack user show cloudkitty
    - env:
        cloudkitty_pass: {{ passwords.cloudkitty_pass }}
        OS_CLOUD: test

openstack-cloudkitty-bootstrap-db:
  cmd.run:
    - name: |
        cloudkitty-storage-init && \
        cloudkitty-dbsync upgrade
        systemctl restart cloudkitty-api cloudkitty-processor
    - onchanges:
        - cmd: openstack-cloudkitty-bootstrap
