{% for disk in salt['pillar.get']('ceph:osds:' + grains['id']) %}

ceph-cluster-zap-existing-disk-{{ disk }}:
  cmd.run:
    - name: ceph-volume lvm zap --destroy {{ disk }}
    - onlyif: which ceph-volume

{% endfor %}
