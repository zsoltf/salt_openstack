{% load_yaml as map %}

base:
  release: nautilus
  openstack:
    pools:
      - backups
      - images
      - vms
      - volumes

boneyard:

  public_networks: '10.5.45.0/24,10.250.18.0/23'
  storage_network: '10.5.45.0/24'

  osds:

    ceph-osd-s1:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd

    ceph-osd-s2:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd

    ceph-osd-s3:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd

openstack:
  public_networks: '10.5.45.0/24,10.250.18.0/23'
  storage_network: '10.5.45.0/24'


{% endload %}
{% set ceph = salt['grains.filter_by'](map, grain='datacenter', base='base') %}

ceph:
  {{ ceph|yaml }}


# network mines
mine_functions:
  storage_network:
    mine_function: network.ip_addrs
    cidr: {{ ceph['storage_network'] }}
