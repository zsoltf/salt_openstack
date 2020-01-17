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
          connection: 'mysql+pymysql://cinder:{{ cinder_db_pass }}@{{ database }}/cinder'
        DEFAULT:
          auth_strategy: keystone
          transport_url: rabbit://openstack:{{ rabbit_pass }}@{{ controller }}:5672/
          my_ip: {{ storage_ip }}
          glance_api_servers: http://{{ controller }}:9292
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

openstack-cinder-ceph-storage-config:
  ini.options_present:
    - name: /etc/cinder/cinder.conf
    - sections:
        DEFAULT:
          enabled_backends: ceph
          glance_api_version: 2
          backup_driver: cinder.backup.drivers.ceph
          backup_ceph_conf: /etc/ceph/ceph.conf
          backup_ceph_user: cinder-backup
          backup_ceph_chunk_size: 134217728
          backup_ceph_pool: backups
          backup_ceph_stripe_unit: 0
          backup_ceph_stripe_count: 0
          restore_discard_excess_bytes: true
        ceph:
          volume_driver: cinder.volume.drivers.rbd.RBDDriver
          volume_backend_name: ceph
          rbd_pool: volumes
          rbd_ceph_conf: /etc/ceph/ceph.conf
          rbd_flatten_volume_from_snapshot: false
          rbd_max_clone_depth: 5
          rbd_store_chunk_size: 4
          rados_connect_timeout: -1
          rbd_user: cinder
          rbd_secret_uuid: cd609bed-350c-44cd-b2a9-c8d13834852b

openstack-cinder-restart:
  cmd.run:
    - name: |
        service tgt restart
        service cinder-volume restart
    - onchanges:
        - ini: openstack-cinder-storage-config
