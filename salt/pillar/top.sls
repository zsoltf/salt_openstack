base:

  '*':
    - test
    - mine
    - virt

  'datacenter:*':
    - match: grain
    - openstack
    {%- if salt['grains.get']('openstack:enable_ceph') %}
    - ceph
    {%- endif %}

  'kube:role':
    - match: grain
    - kubernetes
