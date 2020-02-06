{% set cluster_mine = salt['mine.get']('ceph:role', 'storage_network', 'grain') | dictsort() %}
{% set ceph_network = salt['pillar.get']('ceph:storage_network') %}

{% for name, ips in cluster_mine %}
  {% for ip in ips if salt['network.ip_in_subnet'](ip, ceph_network) %}

ceph-etc_hosts_{{ name }}:
  host.present:
    - name: {{ name }}
    - ip: {{ ip }}
    - clean: True

  {% endfor %}
{% endfor %}
