{% load_yaml as os_map %}

default:
  pkgrepo: []

Debian:
  pkgrepo:
    - humanname: Ceph Nautilus
    - name: 'deb https://download.ceph.com/debian-nautilus/ bionic main'
    - keyserver: 'https://download.ceph.com/keys/release.asc'
    - keyid: E84AC2C0460F3994
    - file: /etc/apt/sources.list.d/ceph.list

RedHat:
  pkgrepo:
    - humanname: Ceph Nautilus
    - baseurl: ''
    - gpgcheck: 0
    - gpgkey: ''

{% endload %}
{% set map = salt['grains.filter_by'](os_map) %}

ceph-repo:
  pkgrepo.managed: {{ map['pkgrepo']|yaml }}
