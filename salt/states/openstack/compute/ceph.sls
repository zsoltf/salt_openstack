openstack-nova-compute-ceph-config:
  ini.options_present:
    - name: /etc/nova/nova-compute.conf
    - sections:
        libvirt:
          rbd_user: cinder
          rbd_sercret_uuid: cd609bed-350c-44cd-b2a9-c8d13834852b
