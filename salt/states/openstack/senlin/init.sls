{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-senlin:
  pkg.installed:
    - names:
        - senlin-api
        - senlin-common
        - senlin-engine
        - python3-senlin
        - python3-senlinclient

openstack-senlin-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/senlin/senlin.conf
        sed -i /^$/d /etc/senlin/senlin.conf
    - onchanges:
      - pkg: openstack-senlin

openstack-senlin-initial-config:
  ini.options_present:
    - name: /etc/senlin/senlin.conf
    - sections:
        database:
          connection: 'mysql+pymysql://senlin:{{ passwords.senlin_db_pass }}@{{ database }}/senlin'
        keystone_authtoken:
          service_token_roles_required: 'True'
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: senlin
          password: {{ passwords.senlin_pass }}
          region_name: RegionOne
        authentication:
          auth_url: http://{{ controller }}:5000/v3
          service_username: senlin
          service_password: {{ passwords.senlin_pass }}
          service_project_name: service
        oslo_messaging_rabbit:
          rabbit_userid: openstack
          rabbit_hosts: {{ mq }}
          rabbit_password: {{ passwords.rabbit_pass }}
        oslo_messaging_notifications:
          driver: messaging
        # default senlin port conflicts with placement-api :(
        senlin_api:
          bind_port: 8777
        receiver:
          bind_port: 8777


openstack-senlin-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $senlin_pass senlin
        openstack role add --project service --user senlin admin
        openstack service create --name senlin --description "Senlin Clustering Service V1" clustering
        openstack endpoint create senlin --region RegionOne public http://{{ controller }}:8777
        openstack endpoint create senlin --region RegionOne admin http://{{ controller }}:8777
        openstack endpoint create senlin --region RegionOne internal http://{{ controller }}:8777
    - unless: openstack user show senlin
    - env:
        senlin_pass: {{ passwords.senlin_pass }}
        OS_CLOUD: test

openstack-senlin-bootstrap-db:
  cmd.run:
    - name: |
        senlin-manage db_sync
        systemctl enable senlin-api senlin-engine
        systemctl restart senlin-api senlin-engine
    - onchanges:
        - ini: openstack-senlin-initial-config
        - cmd: openstack-senlin-bootstrap

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-senlin-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q senlin-dashboard
        cp /usr/local/lib/python3.6/dist-packages/senlin_dashboard/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-senlin-bootstrap-db
