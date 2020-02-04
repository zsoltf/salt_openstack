{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-cloudkitty-pip:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install cloudkitty python-cloudkittyclient

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-cloudkitty-pip-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q cloudkitty-dashboard
        cp /usr/local/lib/python3.6/dist-packages/cloudkittydashboard/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart

openstack-cloudkitty-config-dir:
  file.directory:
    - name: /etc/cloudkitty

openstack-cloudkitty-log-dir:
  file.directory:
    - name: /var/log/cloudkitty

openstack-cloudkitty-source-configs:
  cmd.run:
    - name: |
        git clone -b stable/train https://opendev.org/openstack/cloudkitty.git --depth=1
        cd cloudkitty
        tox -e genconfig
        cp etc/cloudkitty/cloudkitty.conf.sample /etc/cloudkitty/cloudkitty.conf
        cp etc/cloudkitty/policy.json /etc/cloudkitty
        cp etc/cloudkitty/api_paste.ini /etc/cloudkitty
        cp etc/cloudkitty/metrics.yml /etc/cloudkitty

openstack-cloudkitty-initial-config:
  ini.options_present:
    - name: /etc/cloudkitty/cloudkitty.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          verbose: 'true'
          debug: 'false'
          log_dir: /var/log/cloudkitty
          auth_strategy: keystone
        database:
          connection: 'mysql+pymysql://cloudkitty:{{ passwords.cloudkitty_db_pass }}@{{ database }}/cloudkitty'
        ks_auth:
          auth_type: v3password
          auth_protocol: http
          auth_url: http://{{ controller }}:5000/v3
          indentity_uri: http://{{ controller }}:5000/v3
          username: cloudkitty
          password: {{ passwords.cloudkitty_pass }}
          project_name: service
          user_domain_name: Default
          project_domain_name: Default
        keystone_authtoken:
          auth_section: ks_auth
        storage:
          version: 2
          backend: pymysql
        storage_elasticsearch:
          host: http://{{ controller }}:9200
        fetcher:
          backend: gnocchi
        fetcher_gnocchi:
          auth_section: ks_auth
          region_name: RegionOne
        collect:
          collector: gnocchi
        collector_gnocchi:
          auth_section: ks_auth
          region_name: RegionOne

openstack-cloudkitty-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $cloudkitty_pass cloudkitty
        openstack role add --project service --user cloudkitty admin
        openstack service create rating --name cloudkitty --description "OpenStack Rating Service"
        openstack endpoint create rating --region RegionOne public http://{{ controller }}:8889
        openstack endpoint create rating --region RegionOne admin http://{{ controller }}:8889
        openstack endpoint create rating --region RegionOne internal http://{{ controller }}:8889
    - unless: openstack user show cloudkitty
    - env:
        cloudkitty_pass: {{ passwords.cloudkitty_pass }}
        OS_CLOUD: test

#openstack-cloudkitty-bootstrap-db:
#  cmd.run:
#    - name: |
#        cloudkitty-storage-init && \
#        cloudkitty-dbsync upgrade
#        systemctl restart cloudkitty-api cloudkitty-processor
#    - onchanges:
#        - cmd: openstack-cloudkitty-bootstrap
#
