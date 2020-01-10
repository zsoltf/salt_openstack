{% load_yaml as map %}

default:
  base:

    release: train

    password:
      admin: hae5Oeru
      cinder_db: ahsh0Imo
      cinder: fieng4Sh
      dash: WeeWer1e
      demo: AepeVae0
      glance_db: Neegah7l
      glance: Oozoo8bo
      keystone_db: PahShup6
      keystone: uJeefai3
      metadata: nohib1Oh
      neutron_db: AiP0dehe
      neutron: auja1Ofi
      nova_db: uw5tho2I
      nova: quooBoh8
      placement: UX3eingu
      rabbit: Nahj8wai

boneyard:
  base:
    admin_network: 10.130.1.0/24

{% endload %}
{% set overrides = salt['grains.filter_by'](map, grain='datacenter', base='default') %}
{% set openstack = salt['grains.filter_by'](overrides, grain='id', base='base') %}

openstack:
  {{ openstack|yaml }}
