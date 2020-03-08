{% from 'openstack/map.jinja' import controller, database, memcache, passwords with context %}

openstack-freezer-components:
  cmd.run:
    - name: |
        git clone -b stable/train https://git.openstack.org/openstack/freezer.git
        cd freezer
        pip3 install -r requirements.txt
        python3 setup.py install
        mkdir /etc/freezer
        cp etc/scheduler.conf.sample /etc/freezer/scheduler.conf

openstack-freezer-api-components:
  cmd.run:
    - name: |
        git clone -b stable/train https://git.openstack.org/openstack/freezer-api.git
        cd freezer-api
        pip3 install -r requirements.txt
        python3 setup.py install
        mkdir /etc/freezer
        cp etc/freezer/freezer-api.conf.sample /etc/freezer/freezer-api.conf
        cp etc/freezer/freezer-paste.ini /etc/freezer/freezer-paste.ini

openstack-freezer-initial-config:
  ini.options_present:
    - name: /etc/freezer/freezer-api.conf
    - sections:
        storage:
          backend: sqlalchemy
          driver: sqlalchemy
        database:
          connection: 'mysql+pymysql://freezer:{{ passwords.freezer_db_pass }}@{{ database }}/freezer?charset=utf8'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: freezer
          password: {{ passwords.freezer_pass }}

openstack-freezer-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $freezer_pass freezer
        openstack role add --project service --user freezer admin
        openstack service create --name freezer --description "Backup" backup
        openstack endpoint create --region RegionOne backup public http://{{ controller }}:9090/
        openstack endpoint create --region RegionOne backup internal http://{{ controller }}:9090/
        openstack endpoint create --region RegionOne backup admin http://{{ controller }}:9090/
    - unless: openstack user show freezer
    - env:
        freezer_pass: {{ passwords.freezer_pass }}
        OS_CLOUD: test

openstack-freezer-bootstrap-db:
  cmd.run:
    - name: |
        freezer-manage db sync
    - onchanges:
        - cmd: openstack-freezer-bootstrap


openstack-freezer-api-service:
  file.managed:
    - name: /etc/systemd/system/freezer-api.service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - ini: openstack-freezer-api-service
  service.running:
    - name: freezer-api
    - enable: True
    - require:
      - ini: openstack-freezer-api-service
  ini.options_present:
    - name: /etc/systemd/system/freezer-api.service
    - require:
        - file: openstack-freezer-api-service
    - sections:
        Unit:
          Description: Freezer API
        Service:
          ExecStart: /usr/local/bin/freezer-api --config-file /etc/freezer/freezer-api.conf
        Install:
          WantedBy: multi-user.target


#TODO: horizon dashboards are bad, they should go somewhere else
openstack-freezer-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        git clone -b stable/train https://github.com/openstack/freezer-web-ui
        cd freezer-web-ui
        pip3 install -r requirements.txt
        pip3 install .
        cp disaster_recovery/enabled/_5050_freezer.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-freezer-bootstrap-db
