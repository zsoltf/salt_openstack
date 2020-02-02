{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

# not working properly yet

openstack-murano:
  pkg.installed:
    - names:
        - murano-api
        - murano-engine

openstack-murano-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/murano/murano.conf
        sed -i /^$/d /etc/murano/murano.conf
    - onchanges:
      - pkg: openstack-murano

openstack-murano-initial-config:
  ini.options_present:
    - name: /etc/murano/murano.conf
    - sections:
        DEFAULT:
          debug: 'false'
          verbose: 'true'
          rabbit_userid: openstack
          rabbit_hosts: {{ mq }}
          rabbit_password: {{ passwords.rabbit_pass }}
          dirver: messagingv2
        database:
          connection: 'mysql+pymysql://murano:{{ passwords.murano_db_pass }}@{{ database }}/murano'
        keystone:
          auth_url: http://{{ controller }}:5000
        keystone_authtoken:
          service_token_roles_required: 'True'
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: murano
          password: {{ passwords.murano_pass }}
        murano:
          url: http://{{controller }}:8082
        rabbitmq:
          login: openstack
          host: {{ mq }}
          password: {{ passwords.rabbit_pass }}
        #networking:
        #  default_dns: 8.8.8.8

openstack-murano-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $murano_pass murano
        openstack role add --project service --user murano admin
        openstack service create --name murano --description "Application Catalog" application-catalog
        openstack endpoint create --region RegionOne application-catalog public http://{{ controller }}:8082
        openstack endpoint create --region RegionOne application-catalog internal http://{{ controller }}:8082
        openstack endpoint create --region RegionOne application-catalog admin http://{{ controller }}:8082
    - unless: openstack user show murano
    - env:
        murano_pass: {{ passwords.murano_pass }}
        OS_CLOUD: test

openstack-murano-bootstrap-db:
  cmd.run:
    - name: |
        murano-db-manage upgrade
        systemctl enable murano-api murano-engine
        systemctl restart murano-api murano-engine
    - onchanges:
        - ini: openstack-murano-initial-config
        - cmd: openstack-murano-bootstrap

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-murano-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        git clone -b stable/train https://github.com/openstack/murano-dashboard
        cd murano-dashboard
        pip3 install -r requirements.txt
        python3 setup.py install
        cp /usr/local/lib/python3.6/dist-packages/muranodashboard/local/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-murano-bootstrap-db
