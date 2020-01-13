{% load_yaml as map %}

default:
  base:

    internal_network: 10.0.0.0/8
    release: train

    passwords:

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
      mysql_root_db_pass: Aeboob4u

boneyard:
  base:
    internal_network: 10.130.1.0/24

test:
  base:
    internal_network: 192.168.0.0/16

{% endload %}
{% set overrides = salt['grains.filter_by'](map, grain='datacenter', base='default') %}
{% set openstack = salt['grains.filter_by'](overrides, grain='id', base='base') %}

openstack:
  {{ openstack|yaml }}
