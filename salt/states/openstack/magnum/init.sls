{% from 'openstack/map.jinja' import controller_ip, database, mq, memcache, controller, passwords with context %}

openstack-magnum:
  pkg.installed:
    - names:
      - magnum-api
      - magnum-conductor
      - python3-magnumclient

openstack-magnum-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/magnum/magnum.conf
        sed -i /^$/d /etc/magnum/magnum.conf
    - onchanges:
      - pkg: openstack-magnum

openstack-magnum-initial-config:
  ini.options_present:
    - name: /etc/magnum/magnum.conf
    - sections:
        api:
          host: {{ controller_ip }}
        certificates:
          cert_manager_type: barbican
        cinder_client:
          region_name: RegionOne
        database:
          connection: 'mysql+pymysql://magnum:{{ passwords.magnum_db_pass }}@{{ database }}/magnum'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000/v3
          auth_url: http://{{ controller }}:5000/v3
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: magnum
          password: {{ passwords.magnum_pass }}
          admin_username: magnum
          admin_password: {{ passwords.magnum_pass }}
          admin_tenant_name: service
          auth_version: v3
          region_name: RegionOne
        trust:
          trustee_domain_name: magnum
          trustee_domain_admin_name: magnum_domain_admin
          trustee_domain_admin_password: {{ passwords.magnum_domain_pass }}
          trustee_keystone_interface: public
        oslo_messaging_notifications:
          driver: messaging
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/

openstack-magnum-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $magnum_pass magnum
        openstack role add --project service --user magnum admin
        openstack service create --name magnum --description "OpenStack Container Infrastructure Management Service" container-infra
        openstack endpoint create --region RegionOne container-infra public http://{{ controller }}:9511/v1
        openstack endpoint create --region RegionOne container-infra internal http://{{ controller }}:9511/v1
        openstack endpoint create --region RegionOne container-infra admin http://{{ controller }}:9511/v1
        openstack domain create --description "Owns users and projects created by magnum" magnum
        openstack user create --domain magnum --password $magnum_domain_pass magnum_domain_admin
        openstack role add --domain magnum --user-domain magnum --user magnum_domain_admin admin
    - unless: openstack user show magnum
    - env:
        magnum_pass: {{ passwords.magnum_pass }}
        magnum_domain_pass: {{ passwords.magnum_domain_pass }}
        OS_CLOUD: test

openstack-magnum-bootstrap-db:
  cmd.run:
    - name: |
        magnum-db-manage upgrade
        systemctl restart magnum-api magnum-conductor
        systemctl enable magnum-api magnum-conductor
    - onchanges:
        - ini: openstack-magnum-initial-config

##TODO: horizon dashboards are bad, they should go somewhere else
openstack-magnum-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install -q magnum-ui
        cp /usr/local/lib/python3.6/dist-packages/magnum_ui/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-magnum-bootstrap-db
