{% set cluster_mine = salt['mine.get']('ceph:role', 'test.ping', 'grain') | dictsort() %}
{% set nodes = cluster_mine|map('first')|join(' ') %}

ceph-deploy-purge:
  cmd.run:
    - name: |
        ceph-deploy purge {{ nodes }} && \
        ceph-deploy purgedata {{ nodes }} && \
        ceph-deploy forgetkeys && \
        rm ceph.* && \
        cd .. && \
        rm -rf /home/ceph-admin/ceph && \
        rm -rf /home/ceph-admin/.ssh/id_rsa*
    - onlyif: cat /home/ceph-admin/ceph/purge
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
