{% set mon_nodes = salt['mine.get']('ceph:role:mon', 'test.ping', 'grain') | dictsort() %}
{% set osd_nodes = salt['mine.get']('ceph:role:osd', 'test.ping', 'grain') | dictsort() %}

# TODO: add beauty and elegance
{% set mons = mon_nodes|map('first')|join(' ') ~ '.ceph' %}
{% set osds = osd_nodes|map('first')|join(' ') ~ '.ceph' %}
{% set all = mons + ' ' + osds %}

{% set storage_network = salt['pillar.get']('ceph:storage_network') %}
{% set ceph_release = salt['pillar.get']('ceph:release') %}

ceph-common:
  pkg.installed: []

ceph-cluster-dir:
  file.directory:
    - name: /home/ceph-admin/ceph
    - user: ceph-admin

ceph-cluster-new:
  cmd.run:
    - name: ceph-deploy new {{ mons }} --public-network {{ storage_network }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - onchanges:
        - file: ceph-cluster-dir

# network config: public network = {ip-address}/{bits}

ceph-cluster-install:
  cmd.run:
    - name: ceph-deploy install --release {{ ceph_release }} {{ all }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - onchanges:
        - cmd: ceph-cluster-new
