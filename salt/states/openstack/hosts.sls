{% from 'openstack/map.jinja' import admin_network with context %}
{% set cluster_mine = salt['mine.get']('openstack:role', 'admin_network', 'grain') | dictsort() %}

# hosts file

{% for name, ips in cluster_mine %}
{% for ip in ips if salt['network.ip_in_subnet'](ip, admin_network) %}

openstack-etc_hosts_{{ name }}:
  host.present:
    - name: {{ name }}
    - ip: {{ ip }}
    - clean: True

{% endfor %}
{% endfor %}
