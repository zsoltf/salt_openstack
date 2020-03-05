{% from 'openstack/map.jinja' import ceph, admin_ip, mq, database, controller, memcache, passwords with context %}
{% set ceph_rgw = salt['mine.get']('ceph:role:rgw', 'test.ping', 'grain') | default([]) %}
{% if ceph_rgw %}
  {% set ceph_rgw = ceph_rgw|first %}
  {% set ceph_rgw_url = 'http://' ~ ceph_rgw ~ ':80/swift' %}
{% endif %}
{% set swift_hash_prefix = salt['pillar.get']('openstack:swift_hash_prefix') %}
{% set swift_hash_suffix = salt['pillar.get']('openstack:swift_hash_suffix') %}


openstack-swift:
  pkg.installed:
    - names:
        - swift
        - swift-proxy
        - python3-swiftclient
        - python3-keystoneclient
        - python3-keystonemiddleware
        - swift
        - swift-account
        - swift-container
        - swift-object

openstack-swift-config:
  cmd.run:
    - name: |
        mkdir -p /var/cache/swift
        chown -R root:swift /var/cache/swift
        chmod -R 775 /var/cache/swift
        mkdir /etc/swift
        curl -o /etc/swift/proxy-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/proxy-server.conf-sample
        curl -o /etc/swift/account-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/account-server.conf-sample
        curl -o /etc/swift/container-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/container-server.conf-sample
        curl -o /etc/swift/object-server.conf https://opendev.org/openstack/swift/raw/branch/master/etc/object-server.conf-sample
        curl -o /etc/swift/swift.conf https://opendev.org/openstack/swift/raw/branch/master/etc/swift.conf-sample
        chown -R swift:swift /etc/swift
        sed -i /^#/d /etc/swift/proxy-server.conf
        sed -i /^$/d /etc/swift/proxy-server.conf
    - onchanges:
      - pkg: openstack-swift

openstack-swift-proxy-initial-config:
  ini.options_present:
    - name: /etc/swift/proxy-server.conf
    - sections:
        DEFAULT:
          bind_port: 8080
          user: swift
          swift_dir: /etc/swift
        'pipeline:main':
          pipeline: catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server
        'app:proxy-server':
          use: 'egg:swift#proxy'
          account_autocreate: True
        'filter:keystoneauth':
          use: 'egg:swift#keystoneauth'
          operator_roles: admin,user
        'filter:authtoken':
          paste.filter_factory: 'keystonemiddleware.auth_token:filter_factory'
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: swift
          password: {{ passwords.swift_pass }}
        'filter:cache':
          use: 'egg:swift#memcache'
          memcache_servers: {{ memcache }}:11211

openstack-swift-account-initial-config:
  ini.options_present:
    - name: /etc/swift/account-server.conf
    - sections:
        DEFAULT:
          bind_ip: {{ admin_ip }}
          bind_port: 6202
          user: swift
          swift_dir: /etc/swift
        'pipeline:main':
          pipeline: healthcheck recon account-server
        'filter:recon':
          use: 'egg:swift#recon'
          recon_cache_path: /var/cache/swift

openstack-swift-container-initial-config:
  ini.options_present:
    - name: /etc/swift/container-server.conf
    - sections:
        DEFAULT:
          bind_ip: {{ admin_ip }}
          bind_port: 6201
          user: swift
          swift_dir: /etc/swift
        'pipeline:main':
          pipeline: healthcheck recon container-server
        'filter:recon':
          use: 'egg:swift#recon'
          recon_cache_path: /var/cache/swift

openstack-swift-object-initial-config:
  ini.options_present:
    - name: /etc/swift/object-server.conf
    - sections:
        DEFAULT:
          bind_ip: {{ admin_ip }}
          bind_port: 6200
          user: swift
          swift_dir: /etc/swift
        'pipeline:main':
          pipeline: healthcheck recon object-server
        'filter:recon':
          use: 'egg:swift#recon'
          recon_cache_path: /var/cache/swift
          recon_lock_path: /var/lock

openstack-swift-initial-config:
  ini.options_present:
    - name: /etc/swift/swift.conf
    - sections:
        swift-hash:
          swift_hash_path_suffix: {{ swift_hash_suffix }}
          swift_hash_path_prefix: {{ swift_hash_prefix }}
        'storage-policy:0':
          name: Policy-0
          default: 'yes'

openstack-swift-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $swift_pass swift
        openstack role add --project service --user swift admin
        openstack service create --name swift --description "OpenStack Object Storage" object-store
        openstack endpoint create --region RegionOne object-store public {{ ceph_rgw_url }}/v1/AUTH_%\(project_id\)s
        openstack endpoint create --region RegionOne object-store internal {{ ceph_rgw_url }}/v1/AUTH_%\(project_id\)s
        openstack endpoint create --region RegionOne object-store admin {{ ceph_rgw_url }}/v1/AUTH_%\(project_id\)s
    - env:
        swift_pass: {{ passwords.swift_pass }}
        OS_CLOUD: test
    - unless: openstack user show swift

openstack-swift-proxy-service:
    service.running:
      - name: swift-proxy
      - enable: True
      - watch:
          - ini: openstack-swift-initial-config
          - ini: openstack-swift-proxy-initial-config
