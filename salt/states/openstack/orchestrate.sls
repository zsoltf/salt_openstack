# prepare nodes
initial-preparation:
  salt.state:
    - tgt: 'openstack:role'
    - tgt_type: grain
    - sls:
      - openstack

initial-node-preparation:
  salt.state:
    - tgt: |
        G@openstack:role:controller or
        G@openstack:role:compute or
        G@openstack:role:storage
    - tgt_type: compound
    - sls: openstack.node

##############
# monitor node
##############
monitor-node:
  salt.state:
    - tgt: 'openstack:role:monitor'
    - tgt_type: grain
    - sls:
      - openstack.monitor.server
      - openstack.monitor.client
    - require:
      - salt: initial-preparation

monitor-clients:
  salt.state:
    - tgt: 'openstack:role'
    - tgt_type: grain
    - sls:
      - openstack.monitor.client
    - require:
      - salt: initial-preparation

###########
# data node
###########
# install database, message queue, kv store and memcache
etcd-data-node:
  salt.state:
    - tgt: 'openstack:role:etcd'
    - tgt_type: grain
    - sls: openstack.data.etcd

mq-data-node:
  salt.state:
    - tgt: 'openstack:role:mq'
    - tgt_type: grain
    - sls: openstack.data.rabbit

memcache-data-node:
  salt.state:
    - tgt: 'openstack:role:memcache'
    - tgt_type: grain
    - sls: openstack.data.memcache

sql-data-node:
  salt.state:
    - tgt: 'openstack:role:sql'
    - tgt_type: grain
    - sls: openstack.data.sql

# create tables
create-sql-tables:
  salt.state:
    - tgt: 'openstack:role:sql'
    - tgt_type: grain
    - sls:
      - openstack.keystone.sql
      - openstack.placement.sql
      - openstack.glance.sql
      - openstack.neutron.sql
      - openstack.nova.sql
      - openstack.cinder.sql
      - openstack.heat.sql
      - openstack.barbican.sql
      - openstack.designate.sql
      - openstack.senlin.sql
      - openstack.octavia.sql
      - openstack.vitrage.sql
      - openstack.karbor.sql
      - openstack.watcher.sql
      - openstack.mistral.sql
      - openstack.zun.sql
    - require:
      - salt: sql-data-node

############
# controller
############
control-plane:
  salt.state:
    - tgt: 'openstack:role:controller'
    - tgt_type: grain
    - sls:
      - openstack.keystone
      - openstack.placement
      - openstack.glance
      - openstack.horizon
      - openstack.nova.controller
      - openstack.neutron.controller
      - openstack.cinder.controller
    - require:
      - salt: create-sql-tables
      - salt: memcache-data-node
      - salt: mq-data-node

control-plane-extended:
  salt.state:
    - tgt: 'openstack:role:controller'
    - tgt_type: grain
    - sls:
      - openstack.heat
      - openstack.barbican
      - openstack.designate
      - openstack.senlin
      - openstack.octavia
      - openstack.mistral
      - openstack.zun
    - require:
      - salt: create-sql-tables
      - salt: memcache-data-node
      - salt: mq-data-node
      - salt: control-plane

#control-plane-experimental:
#  salt.state:
#    - tgt: 'openstack:role:controller'
#    - tgt_type: grain
#    - sls:
#      - openstack.vitrage
#      - openstack.karbor
#      - openstack.watcher
#    - require:
#      - salt: create-sql-tables
#      - salt: memcache-data-node
#      - salt: mq-data-node
#      - salt: control-plane

##############
# compute node
##############
compute-node:
  salt.state:
    - tgt: 'openstack:role:compute'
    - tgt_type: grain
    - sls:
      - openstack.nova.compute
      - openstack.cinder.compute
      - openstack.neutron.compute
      - openstack.zun.compute
    - require:
      - salt: control-plane

# discover compute node
discover-nova:
  salt.state:
    - tgt: 'openstack:role:controller'
    - tgt_type: grain
    - sls: openstack.nova.discover
    - require:
      - salt: compute-node

##############
# storage node
##############
storage-node:
  salt.state:
    - tgt: 'openstack:role:storage'
    - tgt_type: grain
    - sls: openstack.cinder.storage
    - require:
      - salt: control-plane

{% if salt['grains.get']('openstack:enable_ceph') %}
storage-swift:
  salt.state:
    - tgt: 'openstack:role:controller'
    - tgt_type: grain
    - sls: openstack.swift
    - require:
      - salt: control-plane
{% endif %}
