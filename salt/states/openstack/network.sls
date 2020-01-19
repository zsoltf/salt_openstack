{% from 'openstack/map.jinja' import overlay_interface, provider_interface with context %}

# interfaces

openstack-provider-interface:
  pkg.installed:
    - name: ifupdown

{{ provider_interface }}:
  network.managed:
    - enabled: True
    - type: eth
    - enable_ipv6: False
    - proto: manual

{{ overlay_interface }}:
  network.managed:
    - enabled: True
    - type: eth
    - enable_ipv6: False
    - proto: dhcp

{{ provider_interface }}_start:
  file.append:
    - name: /etc/network/interfaces
    - text: |
        up ip link set dev {{ provider_interface }} up
        down ip link set dev {{ provider_interface }} down
    - require:
      - network: {{ overlay_interface }}
      - network: {{ provider_interface }}
