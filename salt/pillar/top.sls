base:

  '*':
    - test
    - ip-mine

  'datacenter:*':
    - match: grain
    - openstack
