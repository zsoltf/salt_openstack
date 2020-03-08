{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-masakari:
  pkg.installed:
    - names:
        - masakari-api
        - masakari-engine

#openstack-masakari-clear-comments:
#  cmd.run:
#    - name: |
#        sed -i /^#/d /etc/masakari/masakari.conf
#        sed -i /^$/d /etc/masakari/masakari.conf
#    - onchanges:
#      - pkg: openstack-masakari

openstack-masakari-initial-config:
  ini.options_present:
    - name: /etc/masakari/masakari.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          graceful_shutdown_timeout: 5
          os_privileged_user_tenant: service
          os_privileged_user_password: {{ passwords.nova_pass }}
          os_privileged_user_auth_url: http://{{ controller }}:5000
          os_privileged_user_name: nova
          use_syslog: False
          debug: True
          masakari_api_workers: 2
        database:
          connection: 'mysql+pymysql://masakari:{{ passwords.masakari_db_pass }}@{{ database }}/masakari'
        taskflow:
          connection: 'mysql+pymysql://masakari:{{ passwords.masakari_db_pass }}@{{ database }}/masakari'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: masakari
          password: {{ passwords.masakari_pass }}

openstack-masakari-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $masakari_pass masakari
        openstack role add --project service --user masakari admin
        openstack service create --name masakari --description "masakari high availability" instance-ha
        openstack endpoint create --region RegionOne masakari public http://{{ controller }}/instance-ha/v1/$\(tenant_id\)s
        openstack endpoint create --region RegionOne masakari internal http://{{ controller }}/instance-ha/v1/$\(tenant_id\)s
        openstack endpoint create --region RegionOne masakari admin http://{{ controller }}/instance-ha/v1/$\(tenant_id\)s
    - unless: openstack user show masakari
    - env:
        masakari_pass: {{ passwords.masakari_pass }}
        OS_CLOUD: test

openstack-maskari-bootstrap-db:
  cmd.run:
    - name: |
        masakari-manage db sync
        systemctl enable masakari-api masakari-engine
        systemctl start masakari-api masakari-engine
    - onchanges:
        - ini: openstack-masakari-initial-config

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-masakari-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q masakari-dashboard
        cp /usr/local/lib/python3.6/dist-packages/masakaridashboard/local/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-masakari-bootstrap-db

