base:
  '*':
    - test

  'openstack:role:controller':
    - match: grain
    - openstack
    - openstack.data
    - openstack.control.keystone

  'openstack:role:compute':
    - match: grain
    - openstack.compute
