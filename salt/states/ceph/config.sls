ceph-config:
  ini.options_present:
    - name: /etc/ceph/ceph.conf
    - sections:
        global:
          public_network: {{ salt['pillar.get']('ceph:public_networks') }}
          cluster_network: {{ salt['pillar.get']('ceph:cluster_network') }}
          mon_pg_warn_max_per_osd: 0
          mon_pg_warn_min_per_osd: 0
          auth_cluster_required: cephx
          auth_service_required: cephx
          auth_client_required: cephx
          osd_pool_default_pg_num: 256
          osd_pool_default_pgp_num: 256
          osd_pool_default_size: 2
          osd_pool_default_min_size: 1
          rbd_default_features: 7
        mon:
          mon allow pool delete: true
  cmd.run:
    - name: systemctl restart ceph-*
    - onchanges:
        - ini: ceph-config
