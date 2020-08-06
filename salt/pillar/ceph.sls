{% load_yaml as map %}

base:
  release: octopus
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

sv:
  public_networks: '10.5.48.0/23,10.131.5.0/24'
  storage_network: '10.131.5.0/24'
  ceph_network: '10.131.7.0/24'

  osds:

    sv-os1-cmp-1:
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf
      - /dev/sdg
      - /dev/sdh
      - /dev/sdi
      - /dev/sdj
      - /dev/sdk
      - /dev/sdl
      - /dev/sdm
      - /dev/sdn

    sv-os1-cmp-2:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf
      - /dev/sdg
      - /dev/sdh
      - /dev/sdi
      - /dev/sdj
      - /dev/sdk
      - /dev/sdl
      - /dev/sdm

    sv-os1-cmp-3:
      - /dev/sdb
      - /dev/sdc
      - /dev/sdd
      - /dev/sde
      - /dev/sdf
      - /dev/sdg
      - /dev/sdh
      - /dev/sdi
      - /dev/sdj
      - /dev/sdk
      - /dev/sdl
      - /dev/sdm


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
