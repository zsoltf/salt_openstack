{% set mon = salt['mine.get']('ceph:role:mon', 'test.ping', 'grain') | join(' ') %}

ceph-cluster-initial-mons:
  cmd.run:
    - name: ceph-deploy mon create-initial
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - creates: /etc/ceph/ceph.conf
