{% load_yaml as map %}

default:
  base:

    admin_network: 192.168.122.0/24
    overlay_network: 10.1.1.0/24
    provider_interface: enp2s0

    release: train

    passwords:

      # pwgen

      admin_pass: hae5Oeru
      cinder_db_pass: ahsh0Imo
      cinder_pass: fieng4Sh
      dash_pass: WeeWer1e
      demo_pass: AepeVae0
      glance_db_pass: Neegah7l
      glance_pass: Oozoo8bo
      keystone_db_pass: PahShup6
      keystone_pass: uJeefai3
      metadata_pass: nohib1Oh
      neutron_db_pass: AiP0dehe
      neutron_pass: auja1Ofi
      nova_db_pass: uw5tho2I
      nova_pass: quooBoh8
      placement_db_pass: eike0aeY
      placement_pass: UX3eingu
      rabbit_pass: Nahj8wai
      mysql_root_db_pass: 'jS5B*rjXWfjo'
      heat_pass: aix3zieM
      heat_admin_pass: kohDae8y
      heat_db_pass: Ieh7Ohc5
      barbican_pass: eeWuk7Re
      barbican_db_pass: ab7aoNu1

boneyard:
  base:
    admin_network: 10.250.18.0/23
    overlay_network: 10.130.1.0/24
    provider_interface: eno3

  openstack-t1*:
    provider_interface: enp3s0f1

  carrier-1*:
    provider_interface: eno2

  carrier-3*:
    provider_interface: enp2s0f1

test:
  base:
    admin_network: 192.168.0.0/16

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
virt:
  disk:
    ceph:
      - data:
          size: 30720
  nic:
    default:
      eth0:
        bridge: br0
        model: virtio
    neutron:
      eth0:
        bridge: br0
        model: virtio
