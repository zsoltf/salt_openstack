{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-designate:
  pkg.installed:
    - names:
        - designate
        - bind9
        - bind9utils
        - bind9-doc
        - designate-worker
        - designate-producer
        - designate-mdns

openstack-designate-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/designate/designate.conf
        sed -i /^$/d /etc/designate/designate.conf
    - onchanges:
      - pkg: openstack-designate

openstack-designate-initial-config:
  ini.options_present:
    - name: /etc/designate/designate.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        'storage:sqlalchemy':
          connection: 'mysql+pymysql://designate:{{ passwords.designate_db_pass }}@{{ database }}/designate'
          sql_connection: 'mysql+pymysql://designate:{{ passwords.designate_db_pass }}@{{ database }}/designate'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: designate
          password: {{ passwords.designate_pass }}
        'service:api':
          listen: 0.0.0.0:9001
          auth_strategy: keystone
          enable_api_v2: True
          enable_api_admin: True
          enable_host_header: True
          enabled_extensions_admin: quotas, reports


openstack-designate-bootstrap:
  cmd.run:
    - name: |
        rndc-confgen -a -k designate -c /etc/bind/designate_rndc.key -r /dev/urandom
        chown 644 /etc/bind/designate_rndc.key
        openstack user create --domain default --password $designate_pass designate
        openstack role add --project service --user designate admin
        openstack service create --name designate --description "DNS" dns
        openstack endpoint create --region RegionOne dns public http://{{ controller }}:9001/
    - unless: openstack user show designate
    - env:
        designate_pass: {{ passwords.designate_pass }}
        OS_CLOUD: test


openstack-designate-bind-config:
  file.managed:
    - name: /etc/bind/named.conf.options
    - mode: '0644'
    - contents: |
        include "/etc/bind/designate_rndc.key";

        options {
          allow-new-zones yes;
          request-ixfr no;
          listen-on port 53 { 127.0.0.1; };
          recursion no;
          allow-query { 127.0.0.1; };
          directory "/var/cache/bind";
          dnssec-validation auto;
          auth-nxdomain no;
          listen-on-v6 { any; };
        };

        controls {
          inet 127.0.0.1 port 953
            allow { 127.0.0.1; } keys { "designate"; };
        };

openstack-designate-pool-config:
  file.managed:
    - name: /etc/designate/pools.yaml
    - contents: |
        - name: default
          description: Default Pool
          attributes: {}
          ns_records:
            - hostname: ns1-1.example.org.
              priority: 1
          nameservers:
            - host: 127.0.0.1
              port: 53
          targets:
            - type: bind9
              description: BIND9 Server 1
              masters:
                - host: 127.0.0.1
                  port: 5354
              options:
                host: 127.0.0.1
                port: 53
                rndc_host: 127.0.0.1
                rndc_port: 953
                rndc_key_file: /etc/bind/designate_rndc.key

openstack-designate-bootstrap-db:
  cmd.run:
    - name: |
        designate-manage database sync
        systemctl start designate-central designate-api
        designate-manage pool update
    - onchanges:
        - ini: openstack-designate-initial-config

{% for service in ['bind9', 'designate-worker', 'designate-producer', 'designate-mdns'] %}
openstack-designate-service-{{ service }}:
  service.running:
    - name: {{ service }}
    - enable: True
    - watch:
      - file: openstack-designate-pool-config
      - ini: openstack-designate-initial-config
      - file: openstack-designate-bind-config
{% endfor %}

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-designate-dashboard:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - append_if_not_found: True
    - pattern: ^DESIGNATE = .*
    - repl: "DESIGNATE = { 'records_use_fips': True }"
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q designate-dashboard
        cp /usr/local/lib/python3.6/dist-packages/designatedashboard/enabled/_1*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-designate-bootstrap-db
      - file: openstack-designate-dashboard