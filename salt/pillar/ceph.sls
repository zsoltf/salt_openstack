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

  public_networks: '10.130.5.0/24,10.250.18.0/23'
  storage_network: '10.130.5.0/24'

  osds:

    frigate-1:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    frigate-2:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    frigate-3:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    frigate-4:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    frigate-5:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    frigate-6:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    carrier-1:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf

    carrier-3:
      - /dev/sda
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sdf

openstack:
  public_networks: '10.5.45.0/24,10.250.18.0/23'
  storage_network: '10.5.45.0/24'


{% endload %}
{% set ceph = salt['grains.filter_by'](map, grain='datacenter', base='base') %}

ceph:
  {{ ceph|yaml }}


{% if ceph.get('storage_network') %}

# network mines
mine_functions:
  storage_network:
    mine_function: network.ip_addrs
    cidr: {{ ceph.get('storage_network') }}

{% endif %}
