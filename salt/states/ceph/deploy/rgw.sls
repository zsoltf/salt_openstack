{% set rgw = salt['mine.get']('ceph:role:rgw', 'test.ping', 'grain') | join(' ') %}

{% if rgw %}

ceph-cluster-rgws:
  cmd.run:
    - name: ceph-deploy rgw create {{ rgw }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - unless: sudo ceph osd pool ls | grep rgw

{% endif %}
