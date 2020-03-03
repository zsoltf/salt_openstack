base:

  '*':
    - test
    - mine
    - virt

  'datacenter:*':
    - match: grain
  {%- if salt['pillar.get']('openstack:enable_ceph') %}
    - ceph
  {%- endif %}
    - openstack
