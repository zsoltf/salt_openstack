{% load_yaml as map %}

default:
  base:

    admin_network: 192.168.122.0/24
    overlay_network: 10.1.1.0/24
    # admin interface: enp1s0 (not managed)
    provider_interface: enp2s0
    # overlay interface: enp3s0 (not managed)

    provider_name: provider
    external_net_name: external
    external_net_type: flat
    external_net_subnet: 192.168.100.0/24
    external_net_gateway: 192.168.100.1
    external_net_nameservers: 192.168.100.1
    external_net_pool_start: 192.168.100.150
    external_net_pool_end: 192.168.100.250

    #TODO: set a grain for this
    enable_ceph: False

    release: ussuri


boneyard:
  base:
    admin_network: 10.250.18.0/23
    overlay_network: 10.130.1.0/24
    provider_interface: eno3
    external_net_name: boneyard
    external_net_subnet: 10.250.18.0/23
    external_net_gateway: 10.250.18.1
    external_net_nameservers: 10.5.48.8
    external_net_pool_start: 10.250.18.49
    external_net_pool_end: 10.250.18.99
    enable_ceph: True

  carrier-1*:
    provider_interface: eno2

  carrier-3*:
    provider_interface: enp2s0f1

home:
  base:
    admin_network: 192.168.100.0/24
    overlay_network: 192.168.10.0/24

  mimas:
    provider_interface: enp5s0

  phoebe:
    provider_interface: eno2

sv:
  base:
    admin_network: 10.5.48.0/23
    overlay_network: 10.131.1.0/24
    external_net_name: physical
    external_net_subnet: 10.5.48.0/23
    external_net_gateway: 10.5.48.1
    external_net_nameservers: 10.5.48.8
    external_net_pool_start: 10.5.49.10
    external_net_pool_end: 10.5.49.199
    enable_ceph: True

  sv-os1-ctr-1*:
    provider_interface: enp3s0f1
  sv-os1-cmp-1*:
    provider_interface: eno2
  sv-os1-cmp-2*:
    provider_interface: enp3s0f0
  sv-os1-cmp-3*:
    provider_interface: enp65s0f1

test:
  stack-storage*:
    cinder_volumes:
      - /dev/vdb
      - /dev/vdc
      - /dev/vdd
      - /dev/vde

{% endload %}
{% set overrides = salt['grains.filter_by'](map, grain='datacenter', base='default') %}
{% set openstack = salt['grains.filter_by'](overrides, grain='id', base='base') %}

# main pillar

openstack:
  {{ openstack|yaml }}


# overrides

# network mines
mine_functions:
  admin_network:
    mine_function: network.ip_addrs
    cidr: {{ openstack['admin_network'] }}
  overlay_network:
    mine_function: network.ip_addrs
    cidr: {{ openstack['overlay_network'] }}

# virt profiles
#virt:
#  disk:
#    ceph:
#      - data:
#          size: 30720
#  nic:
#    default:
#      eth0:
#        bridge: br0
#        model: virtio
#    neutron:
#      eth0:
#        bridge: br0
#        model: virtio
