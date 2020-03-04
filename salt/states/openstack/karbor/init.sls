{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-karbor-components:
  cmd.run:
    - name: |
        git clone -b stable/train https://git.openstack.org/openstack/karbor
        cd karbor
        pip3 install -r requirements.txt
        pip3 install -e .
        python3 setup.py install
        oslo-config-generator --config-file etc/oslo-config-generator/karbor.conf
        oslopolicy-sample-generator --config-file=etc/karbor-policy-generator.conf
        mkdir /etc/karbor
        cp etc/api-paste.ini /etc/karbor
        cp etc/karbor.conf.sample /etc/karbor/karbor.conf
        cp etc/policy.yaml.sample /etc/karbor/policy.yaml
        cp -r etc/providers.d /etc/karbor
        mkdir /var/log/karbor
    - unless: whereis karbor-api

openstack-karbor-client-components:
  cmd.run:
    - name: |
        git clone https://git.openstack.org/openstack/python-karborclient.git
        cd python-karborclient
        python3 setup.py install
    - onchanges:
      - cmd: openstack-karbor-components

openstack-karbor-user:
  cmd.run:
    - name: |
        groupadd karbor
        useradd karbor -g karbor -d /var/lib/karbor -s /sbin/nologin
    - unless: id karbor

#openstack-karbor-clear-comments:
#  cmd.run:
#    - name: |
#        sed -i /^#/d /etc/karbor/karbor.conf
#        sed -i /^$/d /etc/karbor/karbor.conf
#    - onchanges:
#      - cmd: openstack-karbor-components

openstack-karbor-initial-config:
  ini.options_present:
    - name: /etc/karbor/karbor.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        database:
          connection: 'mysql+pymysql://karbor:{{ passwords.karbor_db_pass }}@{{ database }}/karbor'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: karbor
          password: {{ passwords.karbor_pass }}
        trustee:
          auth_type: password
          auth_url: http://{{ controller }}:5000
          username: karbor
          password: {{ passwords.karbor_pass }}
          user_domain_name: default
        clients_keystone:
          auth_uri: http://{{ controller }}:5000
        karbor_client:
          version: 1
          service_type: data-protect
          service_name: karbor

openstack-karbor-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $karbor_pass karbor
        openstack role add --project service --user karbor admin
        openstack service create --name karbor --description "Application Data Protection Service" data-protect
        openstack endpoint create --region RegionOne data-protect public http://{{ controller }}:8799/v1/%\(project_id\)s
        openstack endpoint create --region RegionOne data-protect internal http://{{ controller }}:8799/v1/%\(project_id\)s
        openstack endpoint create --region RegionOne data-protect admin http://{{ controller }}:8799/v1/%\(project_id\)s
    - unless: openstack user show karbor
    - env:
        karbor_pass: {{ passwords.karbor_pass }}
        OS_CLOUD: test

openstack-karbor-bootstrap-db:
  cmd.run:
    - name: |
        karbor-manage db sync
    - onchanges:
        - ini: openstack-karbor-initial-config

{% for service in ["karbor-api", "karbor-protection", "karbor-operationengine"] %}
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
          ExecStart: /usr/local/bin/{{ service }} --config-file /etc/karbor/karbor.conf
        Install:
          WantedBy: multi-user.target
{% endfor %}


#TODO: horizon dashboards are bad, they should go somewhere else
openstack-heat-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        git clone -b stable/train https://github.com/openstack/karbor-dashboard
        cd karbor-dashboard
        pip3 install -r requirements.txt
        pip3 install .
        cp karbor_dashboard/enabled/* /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-karbor-bootstrap-db

