{% from 'openstack/map.jinja' import admin_ip, mq, database, controller, memcache, passwords with context %}

openstack-cinder-volume:
  pkg.installed:
    - name: cinder-volume

openstack-cinder-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/cinder/cinder.conf
        sed -i /^$/d /etc/cinder/cinder.conf
    - onchanges:
      - pkg: openstack-cinder

openstack-cinder-storage-config:
  ini.options_present:
    - name: /etc/cinder/cinder.conf
    - sections:
        database:
          connection: 'mysql+pymysql://cinder:{{ passwords.cinder_db_pass }}@{{ database }}/cinder'
        DEFAULT:
          auth_strategy: keystone
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          my_ip: {{ admin_ip }}
          glance_api_servers: http://{{ controller }}:9292
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: cinder
          password: {{ passwords.cinder_pass }}
        oslo_concurrency:
          lock_path: /var/lib/cinder/tmp

openstack-cinder-restart:
  cmd.run:
    - name: |
        service tgt restart
        service cinder-volume restart
    - onchanges:
        - ini: openstack-cinder-storage-config
