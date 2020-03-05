{% from 'openstack/map.jinja' import controller, database, mq, memcache, passwords with context %}

openstack-vitrage-components:
  cmd.run:
    - name: |
        git clone https://git.openstack.org/openstack/vitrage.git
        cd vitrage
        pip3 install -r requirements.txt
        pip3 install -e .
        python3 setup.py install
        oslo-config-generator --config-file etc/vitrage/vitrage-config-generator.conf
        oslopolicy-sample-generator --config-file etc/vitrage/vitrage-policy-generator.conf
        mkdir /etc/vitrage
        chmod 755 /etc/vitrage
        mkdir /etc/vitrage/static_datasources
        chmod 755 /etc/vitrage/static_datasources
        mkdir /var/log/vitrage
        chmod 755 /var/log/vitrage
        cp etc/vitrage/api-paste.ini /etc/vitrage/
        cp -r etc/vitrage/datasources_values /etc/vitrage/
        cp etc/vitrage/vitrage.conf /etc/vitrage/
        cp etc/vitrage/policy.yaml.sample /etc/vitrage/policy.yaml

openstack-vitrage-initial-config:
  ini.options_present:
    - name: /etc/vitrage/vitrage.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        datasources:
          types: nova.host,nova.instance,nova.zone,static,aodh,cinder.volume,neutron.network,neutron.port,heat.stack,doctor
        database:
          connection: 'mysql+pymysql://vitrage:{{ passwords.vitrage_db_pass }}@{{ database }}/vitrage'
        service_credentials:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: vitrage
          password: {{ passwords.vitrage_pass }}
          region_name: RegionOne
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: vitrage
          password: {{ passwords.vitrage_pass }}
          region_name: RegionOne

openstack-vitrage-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $vitrage_pass vitrage
        openstack role add admin --user vitrage --project service
        openstack role add admin --user vitrage --project admin
        openstack service create rca --name vitrage --description="Root Cause Analysis Service"
        openstack endpoint create vitrage --region RegionOne public http://{{ controller }}:8999
        openstack endpoint create vitrage --region RegionOne internal http://{{ controller }}:8999
        openstack endpoint create vitrage --region RegionOne admin http://{{ controller }}:8999
    - unless: openstack user show vitrage
    - env:
        vitrage_pass: {{ passwords.vitrage_pass }}
        OS_CLOUD: test

openstack-vitrage-bootstrap-db:
  cmd.run:
    - name: vitrage-dbsync
    - onchanges:
        - ini: openstack-vitrage-initial-config

{% for service in ["vitrage-api", "vitrage-graph", "vitrage-notifier"] %}
openstack-{{ service }}-service:
  file.managed:
    - name: /etc/systemd/system/{{ service }}.service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - ini: openstack-{{ service }}-service
  service.running:
    - name: {{ service }}
    - enable: True
    - require:
      - ini: openstack-{{ service }}-service
  ini.options_present:
    - name: /etc/systemd/system/{{ service }}.service
    - require:
        - file: openstack-{{ service }}-service
    - sections:
        Unit:
          Description: {{ service }}
        Service:
          ExecStart: /usr/local/bin/{{ service }}
        Install:
          WantedBy: multi-user.target
{% endfor %}


#TODO: horizon dashboards are bad, they should go somewhere else
openstack-vitrage-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        git clone -b stable/train https://github.com/openstack/vitrage-dashboard
        cd vitrage-dashboard
        pip3 install -r requirements.txt
        pip3 install .
        cp vitrage_dashboard/enabled/_[1-9]* /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-vitrage-bootstrap
