openstack-nova-bootstrap:
  cmd.run:
    - name: |
        openstack compute service list --service nova-compute && \
        nova-manage cell_v2 discover_hosts --verbose
    - env:
        OS_CLOUD: test

