openstack-cinder-ceph-storage-config:
  ini.options_present:
    - name: /etc/cinder/cinder.conf
    - sections:
        DEFAULT:
          enabled_backends: ceph
          glance_api_version: 2
          backup_driver: cinder.backup.drivers.ceph
          backup_ceph_conf: /etc/ceph/ceph.conf
          backup_ceph_user: cinder-backup
          backup_ceph_chunk_size: 134217728
          backup_ceph_pool: backups
          backup_ceph_stripe_unit: 0
          backup_ceph_stripe_count: 0
          restore_discard_excess_bytes: true
        ceph:
          volume_driver: cinder.volume.drivers.rbd.RBDDriver
          volume_backend_name: ceph
          rbd_pool: volumes
          rbd_ceph_conf: /etc/ceph/ceph.conf
          rbd_flatten_volume_from_snapshot: false
          rbd_max_clone_depth: 5
          rbd_store_chunk_size: 4
          rados_connect_timeout: -1
          rbd_user: cinder
          rbd_secret_uuid: cd609bed-350c-44cd-b2a9-c8d13834852b
