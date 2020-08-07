{% from 'openstack/map.jinja' import ceph, ceph_secret_uuid, ceph_admin_path, admin_ip, mq, database, controller, memcache, passwords with context %}

openstack-cinder-volume:
  pkg.installed:
    - names:
      - lvm2
      - thin-provisioning-tools
      - cinder-volume

openstack-cinder-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/cinder/cinder.conf
        sed -i /^$/d /etc/cinder/cinder.conf
    - onchanges:
      - pkg: openstack-cinder-volume

openstack-cinder-storage-config:
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
          glance_api_servers: http://{{ controller }}:9292
        {% if ceph %}
          glance_api_version: 2
          enabled_backends: ceph
          default_volume_type: ceph
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
        {% else %}
          enabled_backends: lvm
          default_volume_type: lvm
        lvm:
          volume_backend_name: lvm
          volume_driver: cinder.volume.drivers.lvm.LVMVolumeDriver
          volume_group: cinder-volumes
          target_protocol: iscsi
          target_helper: tgtadm
        {% endif %}

{% if ceph %}

openstack-cinder-volume-ceph-packages:
  pkg.installed:
    - names:
        - ceph-common
        - python3-rbd
        - python3-rados

openstack-cinder-volume-ceph-secrets:
  file.managed:
    - name: /etc/ceph/ceph.client.cinder.keyring
    - source: salt://minionfs/{{ ceph_admin_path }}/ceph.client.cinder.keyring
    - group: cinder
    - mode: '0640'
    - onchanges_in:
      - cmd: openstack-cinder-restart
    - require:
      - pkg: openstack-cinder-volume-ceph-packages

{% else %}

{% set cinder_volumes = salt['pillar.get']('openstack:cinder_volumes') %}
{% set lvm_volumes = [] %}
{% for vol in cinder_volumes %}
{% do lvm_volumes.append('a/' ~ vol.split('/')[2] ~ '/') %}
{% endfor %}
{% do lvm_volumes.append('r/.*/') %}

openstack-cinder-lvm-config:
  cmd.run:
    - name: |
        sed -i "142i\        filter = {{ lvm_volumes }}" /etc/lvm/lvm.conf
    - unless: |
        grep -F "{{ lvm_volumes }}" /etc/lvm/lvm.conf

openstack-cinder-create-lvm-volumes:
  cmd.run:
    - name: |
        {%- for vol in cinder_volumes %}
        pvcreate {{ vol }}
        {%- endfor %}
        vgcreate cinder-volumes {{ cinder_volumes|join(" ") }}
    - unless: vgdisplay cinder-volumes

{% endif %}

openstack-cinder-restart:
  cmd.run:
    - name: |
        service tgt restart
        service cinder-volume restart
    - onchanges:
        - ini: openstack-cinder-storage-config
