base:
  '*':
    - test

  'openstack:role:controller':
    - match: grain
    - openstack
    - openstack.data
    - openstack.control.keystone
    - openstack.control.placement
    - openstack.control.glance
    - openstack.control.dashboard
    #- openstack.control.nova

  #'openstack:role:compute':
  #  - match: grain
  #  - openstack.compute.nova
