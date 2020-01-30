{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-ceilometer-compute:
  pkg.installed:
    - names:
        - ceilometer-agent-compute
        - ceilometer-agent-ipmi

openstack-ceilometer-compute-initial-config:
  ini.options_present:
    - name: /etc/ceilometer/ceilometer.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        service_credentials:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000/v3
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: ceilometer
          password: {{ passwords.ceilometer_pass }}
          region_name: RegionOne
          interface: internalURL
    - require:
        - pkg: openstack-ceilometer-compute

openstack-ceilometer-compute-nova-config:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        DEFAULT:
          instance_usage_audit: 'True'
          instance_usage_audit_period: hour
        notifications:
          notify_on_state_change: vm_and_task_state
        oslo_messaging_notifications:
          driver: messagingv2
    - require:
        - pkg: openstack-ceilometer-compute



openstack-ceilometer-sudoer:
  file.managed:
    - name: /etc/sudoers.d/ceilometer_sudoers
    - contents: |
        ceilometer ALL = (root) NOPASSWD: /usr/bin/ceilometer-rootwrap /etc/ceilometer/rootwrap.conf *


openstack-ceilometer-compute-restart:
  cmd.run:
    - name: |
        systemctl restart ceilometer-agent-compute ceilometer-agent-ipmi
    - onchanges:
        - ini: openstack-ceilometer-compute-nova-config
        - ini: openstack-ceilometer-compute-initial-config
        - file: openstack-ceilometer-sudoer
