{% set osd_nodes = salt['mine.get']('ceph:role:osd', 'test.ping', 'grain') %}

# Create OSDs

{% for osd_node in osd_nodes %}
  {% set pillarname = osd_node.split('.')[0] %}
  {% for disk in salt['pillar.get']('ceph:osds:' + pillarname) %}

ceph-cluster-osd-{{ osd_node }}-create-osd-{{ disk }}:
  cmd.run:
    - name: ceph-deploy osd create --data {{ disk }} {{ osd_node }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - unless: 'ssh {{ osd_node }} sudo pvs | grep ceph | grep {{ disk }}'

  {% endfor %}
{% endfor %}
