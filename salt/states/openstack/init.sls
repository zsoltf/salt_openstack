{% set cluster_mine = salt['mine.get']('openstack:role', 'ip', 'grain') | dictsort() %}
{% set openstack_network = salt['pillar.get']('openstack:admin_network') %}

{% for name, ips in cluster_mine %}
{% for ip in ips if salt['network.ip_in_subnet'](ip, openstack_network) %}

openstack-etc_hosts_{{ name }}:
  host.present:
    - name: {{ name }}
    - ip: {{ ip }}
    - clean: True

{% endfor %}
{% endfor %}


{% set openstack_release = salt['pillar.get']('openstack:release') %}

openstack-pkgrepo-{{ openstack_release }}:
  pkg.installed:
    - name: ubuntu-cloud-keyring
  pkgrepo.managed:
    - humanname: Openstack {{ openstack_release }}
    - name: deb http://ubuntu-cloud.archive.canonical.com/ubuntu bionic-updates/{{ openstack_release}} main
    - file: /etc/apt/sources.list.d/cloudarchive-{{ openstack_release}}.list
