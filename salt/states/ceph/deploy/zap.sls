{% set osd_nodes = salt['mine.get']('ceph:role:osd', 'test.ping', 'grain') %}

# Zap Disks

{% for osd_node in osd_nodes if salt['pillar.get']('ceph:zap') %}
{% set disks = salt['pillar.get']('ceph:osds:' + osd_node)|join(' ') %}
  {% if disks %}

ceph-cluster-osd-{{ osd_node }}-zap-{{ disks.split(' ')|count }}-disks:
  cmd.run:
    - name: ceph-deploy disk zap {{ osd_node }} {{ disks }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin

  {% endif %}
{% endfor %}
