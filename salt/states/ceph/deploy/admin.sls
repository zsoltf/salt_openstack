{% set admins = salt['mine.get']('ceph:role:admin', 'test.ping', 'grain') | join(' ') %}

ceph-cluster-admin:
  cmd.run:
    - name: ceph-deploy admin {{ admins }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - creates: /etc/ceph/ceph.conf
