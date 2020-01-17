# set up /etc/hosts
{% set cluster_mine = salt['mine.get']('openstack:role', 'admin_network', 'grain') | dictsort() %}
{% set openstack_network = salt['pillar.get']('openstack:admin_network') %}
{% set provider_interface = salt['pillar.get']('openstack:provider_interface') %}

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


# provider interface
openstack-provider-interface:
  pkg.installed:
    - name: ifupdown
  file.managed:
    - name: /etc/network/interfaces
    - contents: |
        auto {{ provider_interface }}
        iface {{ provider_interface }} inet manual
        up ip link set dev $IFACE up
        down ip link set dev $IFACE down


# ntp
include:
  - .ntp
