base:

  '*':
    - test
    - mine

  'datacenter:*':
    - match: grain
    - openstack
