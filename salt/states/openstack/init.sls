# set up /etc/hosts
{% set cluster_mine = salt['mine.get']('openstack:role', 'ip', 'grain') | dictsort() %}
{% set openstack_network = salt['pillar.get']('openstack:internal_network') %}

{% for name, ips in cluster_mine %}
{% for ip in ips if salt['network.ip_in_subnet'](ip, openstack_network) %}

openstack-etc_hosts_{{ name }}:
  host.present:
    - name: {{ name }}
    - ip: {{ ip }}
    - clean: True

{% endfor %}
{% endfor %}


# package repo
{% set release = salt['pillar.get']('openstack:release') %}

openstack-pkgrepo-{{ release }}:
  pkg.installed:
    - name: ubuntu-cloud-keyring
  pkgrepo.managed:
    - humanname: Openstack {{ release }}
    - name: deb http://ubuntu-cloud.archive.canonical.com/ubuntu bionic-updates/{{ release }} main
    - file: /etc/apt/sources.list.d/cloudarchive-{{ release }}.list


# openstack client
openstack-python-client:
  pkg.installed:
    - name: python3-openstackclient

# ntp
include:
  - .ntp
