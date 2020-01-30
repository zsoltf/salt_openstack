{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-ceilometer-cinder-config:
  ini.options_present:
    - name: /etc/cinder/cinder.conf
    - sections:
        oslo_messaging_notifications:
          driver: messagingv2

openstack-ceilometer-cinder-restart:
  cmd.run:
    - name: |
        cinder-volume-usage-audit --send_actions
        systemctl restart cinder-scheduler
    - onchanges:
        - ini: openstack-ceilometer-cinder-config

openstack-ceilometer-glance-config:
  ini.options_present:
    - name: /etc/glance/glance-api.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        oslo_messaging_notifications:
          driver: messagingv2

openstack-ceilometer-glance-restart:
  cmd.run:
    - name: |
        systemctl restart glance-api
    - onchanges:
        - ini: openstack-ceilometer-glance-config

openstack-ceilometer-heat-config:
  ini.options_present:
    - name: /etc/heat/heat.conf
    - sections:
        oslo_messaging_notifications:
          driver: messagingv2

openstack-ceilometer-heat-restart:
  cmd.run:
    - name: |
        systemctl restart heat-api heat-api-cfn heat-engine
    - onchanges:
        - ini: openstack-ceilometer-heat-config

openstack-ceilometer-neutron-config:
  ini.options_present:
    - name: /etc/neutron/neutron.conf
    - sections:
        oslo_messaging_notifications:
          driver: messagingv2

openstack-ceilometer-neutron-restart:
  cmd.run:
    - name: |
        systemctl restart neutron-server
    - onchanges:
        - ini: openstack-ceilometer-neutron-config
