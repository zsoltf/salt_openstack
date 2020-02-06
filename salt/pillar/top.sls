base:

  '*':
    - test
    - mine
    - virt

  'datacenter:*':
    - match: grain
    - ceph
    - openstack
