{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-heat:
  pkg.installed:
    - names:
        - heat-api
        - heat-api-cfn
        - heat-engine

openstack-heat-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/glance/glance-api.conf
        sed -i /^$/d /etc/glance/glance-api.conf
    - onchanges:
      - pkg: openstack-heat

openstack-heat-initial-config:
  ini.options_present:
    - name: /etc/heat/heat.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          heat_metadata_server_url: http://{{ controller }}:8000
          heat_waitcondition_server_url: http://{{ controller }}:8000/v1/waitcondition
          stack_domain_admin: heat_domain_admin
          stack_domain_admin_password: {{ passwords.heat_admin_pass }}
          stack_user_domain_name: heat
        database:
          connection: 'mysql+pymysql://heat:{{ passwords.heat_db_pass }}@{{ database }}/heat'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: heat
          password: {{ passwords.heat_pass }}
        trustee:
          auth_type: password
          auth_url: http://{{ controller }}:5000
          username: heat
          password: {{ passwords.heat_pass }}
          user_domain_name: default
        clients_keystone:
          auth_uri: http://{{ controller }}:5000

openstack-heat-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $heat_pass heat
        openstack role add --project service --user heat admin
        openstack service create --name heat --description "Orchestration" orchestration
        openstack service create --name heat-cfn --description "Orchestration" cloudformation
        openstack endpoint create --region RegionOne orchestration public http://{{ controller }}:8004/v1/%\(tenant_id\)s
        openstack endpoint create --region RegionOne orchestration internal http://{{ controller }}:8004/v1/%\(tenant_id\)s
        openstack endpoint create --region RegionOne orchestration admin http://{{ controller }}:8004/v1/%\(tenant_id\)s
        openstack endpoint create --region RegionOne cloudformation public http://{{ controller }}:8000/v1
        openstack endpoint create --region RegionOne cloudformation internal http://{{ controller }}:8000/v1
        openstack endpoint create --region RegionOne cloudformation admin http://{{ controller }}:8000/v1
        openstack domain create --description "Stack projects and users" heat
        openstack user create --domain heat --password $heat_admin_pass heat_domain_admin
        openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
        openstack role create heat_stack_owner
        openstack role add --project myproject --user myuser heat_stack_owner
        openstack role create heat_stack_user
    - unless: openstack user show heat
    - env:
        heat_pass: {{ passwords.heat_pass }}
        heat_admin_pass: {{ passwords.heat_admin_pass }}
        OS_CLOUD: test

openstack-heat-bootstrap-db:
  cmd.run:
    - name: |
        heat-manage db_sync && \
        service heat-api restart && \
        service heat-api-cfn restart && \
        service heat-engine restart
    - onchanges:
        - ini: openstack-heat-initial-config
