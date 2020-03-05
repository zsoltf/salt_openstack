{% from 'openstack/map.jinja' import database, mq, memcache, controller, controller_ip, passwords with context %}

openstack-watcher:
  pkg.installed:
    - names:
        - watcher-api
        - watcher-decision-engine
        - watcher-applier
        - python3-watcherclient

#openstack-watcher-clear-comments:
#  cmd.run:
#    - name: |
#        sed -i /^#/d /etc/watcher/watcher.conf
#        sed -i /^$/d /etc/watcher/watcher.conf
#    - onchanges:
#      - pkg: openstack-watcher

openstack-watcher-initial-config:
  ini.options_present:
    - name: /etc/watcher/watcher.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          control_exchange: watcher
        database:
          connection: 'mysql+pymysql://watcher:{{ passwords.watcher_db_pass }}@{{ database }}/watcher'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: watcher
          password: {{ passwords.watcher_pass }}
          region_name: RegionOne
        watcher_clients_auth:
          auth_type: password
          auth_url: http://{{ controller }}:5000
          username: watcher
          password: {{ passwords.watcher_pass }}
          project_domain_name: default
          user_domain_name: default
          project_name: service
          region_name: RegionOne
        api:
          host: {{ controller_ip }}
        oslo_messaging_notifications:
          driver: messagingv2

openstack-watcher-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $watcher_pass watcher
        openstack role add --project service --user watcher admin
        openstack service create --name watcher --description "Infrastructure Optimization" infra-optim
        openstack endpoint create --region RegionOne infra-optim public http://{{ controller }}:9322
        openstack endpoint create --region RegionOne infra-optim internal http://{{ controller }}:9322
        openstack endpoint create --region RegionOne infra-optim admin http://{{ controller }}:9322
    - unless: openstack user show watcher
    - env:
        watcher_pass: {{ passwords.watcher_pass }}
        OS_CLOUD: test

openstack-watcher-bootstrap-db:
  cmd.run:
    - name: |
        watcher-db-manage --config-file /etc/watcher/watcher.conf upgrade
        systemctl enable watcher-api.service watcher-decision-engine.service watcher-applier.service
        systemctl start watcher-api.service watcher-decision-engine.service watcher-applier.service
    - onchanges:
        - ini: openstack-watcher-initial-config

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-watcher-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        git clone -b stable/train https://opendev.org/openstack/watcher-dashboard
        cd watcher-dashboard
        pip3 install -r requirements.txt
        pip3 install .
        cp watcher_dashboard/local/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-watcher-bootstrap-db

