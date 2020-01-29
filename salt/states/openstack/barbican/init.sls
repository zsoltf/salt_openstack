{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-barbican:
  pkg.installed:
    - names:
        - barbican-api
        - barbican-keystone-listener
        - barbican-worker
        - python-barbicanclient

openstack-barbican-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/barbican/barbican.conf
        sed -i /^$/d /etc/barbican/barbican.conf
    - onchanges:
      - pkg: openstack-barbican

openstack-barbican-initial-config:
  ini.options_present:
    - name: /etc/barbican/barbican.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          sql_connection: 'mysql+pymysql://barbican:{{ passwords.barbican_db_pass }}@{{ database }}/barbican'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: barbican
          password: {{ passwords.barbican_pass }}

openstack-barbican-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $barbican_pass barbican
        openstack role add --project service --user barbican admin
        openstack role create creator
        openstack role add --project service --user barbican creator
        openstack service create --name barbican --description "Key Manager" key-manager
        openstack endpoint create --region RegionOne key-manager public http://{{ controller }}:9311
        openstack endpoint create --region RegionOne key-manager internal http://{{ controller }}:9311
        openstack endpoint create --region RegionOne key-manager admin http://{{ controller }}:9311
    - unless: openstack user show barbican
    - env:
        barbican_pass: {{ passwords.barbican_pass }}
        OS_CLOUD: test

# TODO set up dogtag as barbican backend

openstack-barbican-bootstrap-db:
  cmd.run:
    - name: |
        barbican-manage db upgrade && \
        service barbican-keystone-listener restart && \
        service barbican-worker restart && \
        service apache2 restart
    - onchanges:
        - ini: openstack-barbican-initial-config


#TODO: horizon dashboards are bad, they should go somewhere else
#NOTE: barbican-ui doesn't seem to work yet
openstack-barbican-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q barbican-ui
        pip3 install -q barbican_ui
        cp /usr/local/lib/python3.6/dist-packages/barbican_ui/enabled/_9*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-barbican-bootstrap-db
