{% for disk in salt['pillar.get']('ceph:osds:' + grains['id']) %}

ceph-cluster-zap-existing-disk-{{ disk }}:
  cmd.run:
    - name: ceph-volume lvm zap --destroy {{ disk }}
    - onlyif: which ceph-volume

ceph-cluster-dd-existing-disk-{{ disk }}:
  cmd.run:
    - name: dd if=/dev/zero of={{ disk }} bs=1M count=2000
    - unless: which ceph-volume

{% endfor %}
