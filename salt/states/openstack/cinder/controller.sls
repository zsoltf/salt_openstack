{% from 'openstack/map.jinja' import ceph, ceph_secret_uuid, ceph_client_cinder_key, admin_ip, mq, database, controller, memcache, passwords with context %}
{% set cinder_host = grains['id'] %}

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
          connection: 'mysql+pymysql://cinder:{{ passwords.cinder_db_pass }}@{{ database }}/cinder'
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
        DEFAULT:
          auth_strategy: keystone
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          my_ip: {{ admin_ip }}
{% if ceph %}
          glance_api_version: 2
          scheduler_default_filters: DriverFilter
          default_volume_type: ceph
          enabled_backends: ceph
        ceph:
          volume_driver: cinder.volume.drivers.rbd.RBDDriver
          volume_backend_name: ceph
          rbd_pool: volumes
          rbd_ceph_conf: /etc/ceph/ceph.conf
          rbd_flatten_volume_from_snapshot: False
          rbd_max_clone_depth: 5
          rbd_store_chunk_size: 4
          rados_connect_timeout: -1
          rbd_user: cinder
          rbd_secret_uuid: {{ ceph_secret_uuid }}

openstack-cinder-ceph-packages:
  pkg.installed:
    - names:
        - python-minimal
        - ceph-common
        - python3-rbd
        - python3-rados

openstack-cinder-ceph-secrets:
  file.managed:
    - name: /etc/ceph/ceph.client.cinder.keyring
    - group: cinder
    - mode: '0640'
    - contents: |
        [client.cinder]
            key = {{ ceph_client_cinder_key }}
{% endif %}

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
        cinder_pass: {{ passwords.cinder_pass }}
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

openstack-cinder-create-volume-type:
  cmd.run:
    - name: |
      {% if ceph %}
        openstack volume type create ceph && \
        openstack volume type set ceph --property volume_backend_name=ceph
      {% else %}
        openstack volume type create lvm && \
        openstack volume type set lvm --property volume_backend_name=lvm
      {% endif %}
    - env:
        OS_CLOUD: test
    - onchanges:
        - cmd: openstack-cinder-bootstrap-db
