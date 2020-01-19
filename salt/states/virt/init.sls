{% set local_interface = 'enp7s0' %}

libvirt-requirements:
  pkg.installed:
    - names:
      - ifupdown
      - python-libvirt
      - bridge-utils


{{ local_interface }}:
  network.managed:
    - enabled: True
    - type: eth
    - bridge: br0

br0:
  network.managed:
    - enabled: True
    - type: bridge
    - proto: dhcp
    - ports: {{ local_interface }}
    - require:
      - network: {{ local_interface }}

libvirt:
  pkg.installed:
    - names:
      - libvirt-daemon-system
      - libvirt-clients
      - qemu-kvm
  virt.keys:
    - require:
      - pkg: libvirt
      - pkg: python-libvirt
  service.running:
    - name: libvirtd
    - require:
      - pkg: libvirt
      - network: br0
      - virt: libvirt
    #- watch:
      #- file: libvirt

libguestfs:
  pkg.installed:
    - pkgs:
      - guestfsd
      - libguestfs-tools

#  file.managed:
#    - name: /etc/sysconfig/libvirtd
#    - contents: 'LIBVIRTD_ARGS="--listen"'
#    - require:
#      - pkg: libvirt
