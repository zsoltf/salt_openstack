{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-aodh:
  pkg.installed:
    - names:
        - aodh-api
        - aodh-evaluator
        - aodh-notifier
        - aodh-listener
        - aodh-expirer
        - python-aodhclient

openstack-aodh-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/aodh/aodh.conf
        sed -i /^$/d /etc/aodh/aodh.conf
    - onchanges:
      - pkg: openstack-aodh

openstack-aodh-initial-config:
  ini.options_present:
    - name: /etc/aodh/aodh.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          auth_strategy: keystone
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
          username: aodh
          password: {{ passwords.aodh_pass }}
        service_credentials:
          auth_type: password
          auth_url: http://{{ controller }}:5000/v3
          project_domain_id: default
          user_domain_id: default
          project_name: service
          username: aodh
          password: {{ passwords.aodh_pass }}
          interface: internalURL
          region_name: RegionOne

openstack-aodh-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $aodh_pass aodh
        openstack role add --project service --user aodh admin
        openstack service create --name aodh --description "Telemetry" alarming
        openstack endpoint create --region RegionOne alarming public http://{{ controller }}:8042
        openstack endpoint create --region RegionOne alarming internal http://{{ controller }}:8042
        openstack endpoint create --region RegionOne alarming admin http://{{ controller }}:8042
    - unless: openstack user show aodh
    - env:
        aodh_pass: {{ passwords.aodh_pass }}
        OS_CLOUD: test

openstack-aodh-bootstrap-db:
  cmd.run:
    - name: |
        aodh-dbsync
        systemctl restart aodh-evaluator aodh-notifier aodh-listener
    - onchanges:
        - ini: openstack-aodh-initial-config
