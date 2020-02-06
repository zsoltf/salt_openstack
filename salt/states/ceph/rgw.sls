ceph-rgw-config:
  ini.options_present:
    - name: /etc/ceph/ceph.conf
    - sections:
        client:
          'rgw frontends': civetweb port=80

ceph-rgw-service:
  cmd.run:
    - name: systemctl restart ceph-radosgw.target
    - onchanges:
        - ini: ceph-rgw-config
