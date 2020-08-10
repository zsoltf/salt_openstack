{% from 'openstack/map.jinja' import admin_ip, database, mq, memcache, controller, passwords with context %}

openstack-zun-user:
  cmd.run:
    - name: |
        groupadd --system zun
        useradd --home-dir "/var/lib/zun" --create-home --system --shell /bin/false -g zun zun
        mkdir -p /etc/zun
        chown zun:zun /etc/zun
        apt install python3-pip git
    - unless: id zun

openstack-zun-components:
  cmd.run:
    - name: |
        cd /var/lib/zun
        git clone -b stable/train https://git.openstack.org/openstack/zun.git
        chown -R zun:zun zun
        cd zun
        pip3 install -r requirements.txt
        python3 setup.py install
        su -s /bin/sh -c "oslo-config-generator --config-file etc/zun/zun-config-generator.conf" zun
        su -s /bin/sh -c "cp etc/zun/zun.conf.sample /etc/zun/zun.conf" zun
        su -s /bin/sh -c "cp etc/zun/api-paste.ini /etc/zun" zun
    - onchanges:
        - cmd: openstack-zun-user

openstack-zun-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/zun/zun.conf
        sed -i /^$/d /etc/zun/zun.conf
    - onchanges:
      - cmd: openstack-zun-components

openstack-zun-initial-config:
  ini.options_present:
    - name: /etc/zun/zun.conf
    - sections:
        api:
          host_ip: {{ admin_ip }}
          port: 9517
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        database:
          connection: 'mysql+pymysql://zun:{{ passwords.zun_db_pass }}@{{ database }}/zun'
        keystone_auth:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: zun
          password: {{ passwords.zun_pass }}
          auth_version: v3
          auth_protocol: http
          service_token_roles_required: 'True'
          endpoint_type: internalURL
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: zun
          password: {{ passwords.zun_pass }}
          auth_version: v3
          auth_protocol: http
          service_token_roles_required: 'True'
          endpoint_type: internalURL
        oslo_concurrency:
          lock_path: /var/lib/zun/tmp
        oslo_messaging_notifications:
          driver: messaging
        websocket_proxy:
          wsproxy_host: {{ admin_ip }}
          wsproxy_port: 6784
          base_url: ws://{{ controller }}:6784/



openstack-zun-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $zun_pass zun
        openstack role add --project service --user zun admin
        openstack user create --domain default --password $kuryr_pass kuryr
        openstack role add --project service --user kuryr admin

        openstack service create --name zun --description "Container Service" container
        openstack endpoint create --region RegionOne container public http://{{ controller }}:9517/v1
        openstack endpoint create --region RegionOne container internal http://{{ controller }}:9517/v1
        openstack endpoint create --region RegionOne container admin http://{{ controller }}:9517/v1
    - unless: openstack user show zun
    - env:
        zun_pass: {{ passwords.zun_pass }}
        kuryr_pass: {{ passwords.kuryr_pass }}
        OS_CLOUD: test

openstack-zun-bootstrap-db:
  cmd.run:
    - name: |
        zun-db-manage upgrade
    - onchanges:
        - cmd: openstack-zun-bootstrap


openstack-zun-api-service:
  service.running:
    - name: zun-api
    - enable: True
    - require:
        - cmd: openstack-zun-api-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-zun-api-service
  file.managed:
    - name: /etc/systemd/system/zun-api.service
    - contents: |
        [Unit]
        Description = OpenStack Container Service API

        [Service]
        ExecStart = /usr/local/bin/zun-api
        User = zun

        [Install]
        WantedBy = multi-user.target

openstack-zun-wsproxy-service:
  service.running:
    - name: zun-wsproxy
    - enable: True
    - require:
        - cmd: openstack-zun-wsproxy-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-zun-wsproxy-service
  file.managed:
    - name: /etc/systemd/system/zun-wsproxy.service
    - contents: |
        [Unit]
        Description = OpenStack Container Service Websocket Proxy

        [Service]
        ExecStart = /usr/local/bin/zun-wsproxy
        User = zun

        [Install]
        WantedBy = multi-user.target


#TODO: horizon dashboards are bad, they should go somewhere else
openstack-zun-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q zun-ui
        cp /usr/local/lib/python3.8/dist-packages/zun_ui/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-zun-bootstrap-db
