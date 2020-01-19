base:

  '*':
    - test
    - mine
    - virt

  'datacenter:*':
    - match: grain
    - openstack
