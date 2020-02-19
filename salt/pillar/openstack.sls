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

    enable_ceph: False

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
      designate_pass: AeB7ieju
      designate_db_pass: sho1ohTh
      octavia_pass: Ohquoh1v
      octavia_db_pass: WieWahm2
      ceilometer_pass: Puungee9
      gnocchi_pass: oop9aHah
      gnocchi_db_pass: xieWai2u
      aodh_pass: Yahch8ie
      aodh_db_pass: jish3ahV
      cloudkitty_pass: aecoh7Lu
      cloudkitty_db_pass: fe3Eegho
      zun_pass: lei3aiCo
      zun_db_pass: Eivei1oh
      kuryr_pass: Ae5xoox9
      senlin_pass: iraeH6ei
      senlin_db_pass: chohNg6t
      murano_pass: euf1ao0Z
      murano_db_pass: jeeyaZ0y
      mistral_pass: Sae2wois
      mistral_db_pass: Lucio5ei
      magnum_pass: ohs2Aedi
      magnum_db_pass: NooS1xei
      magnum_domain_pass: Vaigh1ie

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
    ceph_secret_uuid: 'cd609bed-350c-44cd-b2a9-c8d13834852b'

  openstack-t1*:
    provider_interface: enp3s0f1

  carrier-1*:
    provider_interface: eno2

  carrier-3*:
    provider_interface: enp2s0f1

test:
  base:
    admin_network: 192.168.0.0/16
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
