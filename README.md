# Salted Openstack

Salted Openstack with Ceph for local Kubernetes deployments

### setup ceph

```
# set grains

salt sv-os1-* grains.set datacenter sv

salt sv-os1-ctr-1* grains.append ceph:role '[admin,deploy]'
salt sv-os1-ctr-* grains.append ceph:role '[mon,rgw]'
salt sv-os1-cmp-* grains.append ceph:role osd

salt sv-os1-* grains.set openstack:enable_ceph true

salt sv-os1-ctr-1* grains.append openstack:role '[controller,mq,sql,memcache,etcd]'
salt sv-os1-ctr-2* grains.append openstack:role storage
salt sv-os1-cmp-* grains.append openstack:role compute

# update and verify mine

salt sv-os1* mine.update

salt sv-os1* mine.get \* admin_network
salt sv-os1* mine.get \* overlay_network
salt sv-os1* mine.get \* storage_network

# orchestrate ceph

salt-run state.orch ceph.orchestrate

```

### setup openstack

```
salt-run state.orch openstack.orchestrate
```
