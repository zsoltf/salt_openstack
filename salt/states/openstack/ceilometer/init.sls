{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-ceilometer-gnocchi:
  pkg.installed:
    - names:
        - gnocchi-api
        - gnocchi-metricd
        - python-gnocchiclient

openstack-ceilometer-gnocchi-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/gnocchi/gnocchi.conf
        sed -i /^$/d /etc/gnocchi/gnocchi.conf
    - onchanges:
      - pkg: openstack-ceilometer-gnocchi

openstack-ceilometer-gnocchi-initial-config:
  ini.options_present:
    - name: /etc/gnocchi/gnocchi.conf
    - sections:
        api:
          auth_mode: keystone
        indexer:
          url: 'mysql+pymysql://gnocchi:{{ passwords.gnocchi_db_pass }}@{{ database }}/gnocchi'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000/v3
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: gnocchi
          password: {{ passwords.gnocchi_pass }}
          region_name: RegionOne
          interface: internalURL
        storage:
          #coordination_url: redis://controller:6379
          file_basepath: /var/lib/gnocchi
          driver: file

openstack-ceilometer-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $ceilometer_pass ceilometer && \
        openstack role add --project service --user ceilometer admin && \
        openstack user create --domain default --password $gnocchi_pass gnocchi && \
        openstack role add --project service --user gnocchi admin && \
        openstack service create --name gnocchi --description "Metric Service" metric && \
        openstack endpoint create --region RegionOne metric public http://{{ controller }}:8041 && \
        openstack endpoint create --region RegionOne metric internal http://{{ controller }}:8041 && \
        openstack endpoint create --region RegionOne metric admin http://{{ controller }}:8041
    - unless: openstack user show ceilometer
    - env:
        ceilometer_pass: {{ passwords.ceilometer_pass }}
        gnocchi_pass: {{ passwords.gnocchi_pass }}
        OS_CLOUD: test

openstack-ceilometer-gnocchi-bootstrap-db:
  cmd.run:
    - name: |
        gnocchi-upgrade
        #service gnocchi-api restart
        service gnocchi-metricd restart
    - onchanges:
        - cmd: openstack-ceilometer-bootstrap
        - ini: openstack-ceilometer-gnocchi-initial-config

openstack-ceilometer:
  pkg.installed:
    - names:
        - ceilometer-agent-central
        - ceilometer-agent-notification

openstack-ceilometer-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/gnocchi/gnocchi.conf
        sed -i /^$/d /etc/gnocchi/gnocchi.conf
    - onchanges:
      - pkg: openstack-ceilometer

openstack-ceilometer-pipeline-config:
  file.managed:
    - name: /etc/ceilometer/pipeline.yaml
    - contents: |
        ---
        sources:
          - name: some_pollsters
            meters:
              - "*"
            sinks:
              - pollster_sink
        sinks:
          - name: pollster_sink
            publishers:
              - gnocchi://?filter_project=service&archive_policy=low

openstack-ceilometer-initial-config:
  ini.options_present:
    - name: /etc/ceilometer/ceilometer.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        service_credentials:
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
        - cmd: openstack-ceilometer-gnocchi-bootstrap-db
        - pkg: openstack-ceilometer

openstack-ceilometer-bootstrap-db:
  cmd.run:
    - name: |
        ceilometer-upgrade
        service ceilometer-agent-central restart
        service ceilometer-agent-notification restart
    - onchanges:
        - ini: openstack-ceilometer-initial-config
