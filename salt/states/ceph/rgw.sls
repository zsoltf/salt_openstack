{% from 'openstack/map.jinja' import controller, passwords with context %}

ceph-rgw-config:
  ini.options_present:
    - name: /etc/ceph/ceph.conf
    - sections:
        client:
          'rgw frontends': civetweb port=80
          # Keystone information
          rgw_keystone_api_version: 3
          rgw_keystone_url: http://{{ controller }}:5000
          rgw_keystone_admin_user: admin
          rgw_keystone_admin_password: {{ passwords.admin_pass }}
          rgw_keystone_admin_domain: Default
          rgw_keystone_admin_project: admin
          rgw_keystone_accepted_roles: admin
          rgw_keystone_token_cache_size: 0
          rgw_keystone_revocation_interval: 300
          rgw_keystone_make_new_tenants: 'true'
          #rgw_s3_auth_use_keystone: true
          rgw_s3_auth_use_keystone: 'false'
          #nss_db_path = {path to nss db}
          rgw_keystone_verify_ssl: 'false'
          rgw_swift_account_in_url: 'true'
          rgw_keystone_implicit_tenants: 'true'
          #rgw_keystone_admin_token: 123

ceph-rgw-service:
  cmd.run:
    - name: systemctl restart ceph-radosgw.target
    - onchanges:
        - ini: ceph-rgw-config
