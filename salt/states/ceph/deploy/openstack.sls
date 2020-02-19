{% set openstack_pools = salt['pillar.get']('ceph:openstack:pools', {}) %}

{% set ceph_release = salt['pillar.get']('ceph:release') %}

{% set controller_nodes = salt['mine.get']('openstack:role:controller', 'test.ping', 'grain') | dictsort() %}
{% set compute_nodes = salt['mine.get']('openstack:role:compute', 'test.ping', 'grain') | dictsort() %}
{% set storage_nodes = salt['mine.get']('openstack:role:storage', 'test.ping', 'grain') | dictsort() %}

{% set all = {} %}
{% do all.update(controller_nodes) %}
{% do all.update(compute_nodes) %}
{% do all.update(storage_nodes) %}

{% for name in all %}

ceph-admin-known-host_{{ name }}:
  cmd.run:
    - name: ssh-keyscan -H {{ name }} >> ~/.ssh/known_hosts
    - runas: ceph-admin
    - require_in:
        - cmd: ceph-install-on-openstack
    - onchanges:
        - cmd: ceph-openstack-glance-auth
        - cmd: ceph-openstack-cinder-auth

{% endfor %}

ceph-install-on-openstack:
  cmd.run:
    - name: |
        ceph-deploy install --release {{ ceph_release }} {{ all|join(' ') }} && \
        ceph-deploy config push {{ all|join(' ') }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - onchanges:
        - cmd: ceph-openstack-glance-auth
        - cmd: ceph-openstack-cinder-auth

{% for name in openstack_pools %}

ceph-openstack-{{ name }}:
  cmd.run:
    - name: |
        sudo ceph osd pool create {{ name }} 128 128
        sudo rbd pool init {{ name }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - unless: sudo ceph osd pool get {{ name }} pg_num

{% endfor %}


ceph-openstack-pg-autoscaler:
  cmd.run:
    - name: |
        sudo ceph balancer on
        sudo ceph mgr module enable pg_autoscaler
        {%- for name in openstack_pools %}
        sudo ceph pool set {{ name }} pg_autoscale_mode on
        {%- endfor %}
        sudo ceph balancer mode crush-compat
    - unless: sudo ceph mgr module ls | head -10 | grep pg_autoscaler
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin


ceph-openstack-glance-auth:
  cmd.run:
    - name: |
        sudo ceph auth get-or-create client.glance \
          mon 'profile rbd' \
          osd 'profile rbd pool=images' \
          mgr 'profile rbd' > ~/ceph/ceph.client.glance.keyring
    - creates: /home/ceph-admin/ceph/ceph.client.glance.keyring
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
  module.wait:
    - name: cp.push
    - path: /home/ceph-admin/ceph/ceph.client.glance.keyring
    - watch:
        - cmd: ceph-openstack-glance-auth


ceph-openstack-cinder-auth:
  cmd.run:
    - name: |
        sudo ceph auth get-or-create client.cinder \
          mon 'profile rbd' \
          osd 'profile rbd pool=volumes, profile rbd pool=vms, profile rbd-read-only pool=images' \
          mgr 'profile rbd' > ~/ceph/ceph.client.cinder.keyring
        sudo ceph auth get-key client.cinder > ~/ceph/ceph.client.cinder.key
    - creates:
        - /home/ceph-admin/ceph/ceph.client.cinder.keyring
        - /home/ceph-admin/ceph/ceph.client.cinder.key
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
  module.wait:
    - name: cp.push
    - path: /home/ceph-admin/ceph/ceph.client.cinder.keyring
    - watch:
        - cmd: ceph-openstack-cinder-auth


ceph-openstack-cinder-key:
  module.wait:
    - name: cp.push
    - path: /home/ceph-admin/ceph/ceph.client.cinder.key
    - watch:
        - cmd: ceph-openstack-cinder-auth
