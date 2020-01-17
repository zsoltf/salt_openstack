openstack-cinder-nova-config-compute:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        cinder:
          os_region_name: RegionOne
