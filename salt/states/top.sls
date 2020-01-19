base:
  '*':
    - test

  # openstack apis
  'openstack:role:controller':
    - match: grain
    - openstack.node
    - openstack.keystone
    - openstack.placement
    - openstack.glance
    - openstack.horizon
    - openstack.nova.controller
    - openstack.neutron.controller
    - openstack.cinder.controller

  # message queue
  'openstack:role:mq':
    - match: grain
    - openstack
    - openstack.data.rabbit

  # memcache
  'openstack:role:memcache':
    - match: grain
    - openstack
    - openstack.data.memcache

  # sql
  'openstack:role:sql':
    - match: grain
    - openstack
    - openstack.data.sql
    - openstack.keystone.sql
    - openstack.placement.sql
    - openstack.glance.sql
    - openstack.neutron.sql
    - openstack.nova.sql
    - openstack.cinder.sql

  'openstack:role:compute':
    - match: grain
    - openstack.node
    - openstack.nova.compute
    - openstack.neutron.compute
