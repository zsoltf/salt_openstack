{% from 'openstack/map.jinja' import database, mq, memcache, controller, passwords with context %}

openstack-mistral:
  pkg.installed:
    - pkgs:
        - mistral-api
        - mistral-engine
        - mistral-event-engine
        - mistral-executor
        - python3-mistral
        - python3-mistralclient

#openstack-mistral-clear-comments:
#  cmd.run:
#    - name: |
#        sed -i /^#/d /etc/mistral/mistral.conf
#        sed -i /^$/d /etc/mistral/mistral.conf
#    - onchanges:
#      - cmd: openstack-mistral-install

openstack-mistral-initial-config:
  ini.options_present:
    - name: /etc/mistral/mistral.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
        database:
          connection: 'mysql+pymysql://mistral:{{ passwords.mistral_db_pass }}@{{ database }}/mistral'
        keystone_authtoken:
          service_token_roles_required: 'True'
          region_name: RegionOne
          identity_uri: http://{{ controller }}:5000
          auth_version: v3
          admin_user: mistral
          admin_password: {{ passwords.mistral_pass }}
          admin_tenant_name: service
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: mistral
          password: {{ passwords.mistral_pass }}

openstack-mistral-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $mistral_pass mistral
        openstack role add --project service --user mistral admin
        openstack service create workflowv2 --name mistral --description 'OpenStack Workflow service'
        openstack endpoint create --region RegionOne workflowv2 public http://{{ controller }}:8989/v2
        openstack endpoint create --region RegionOne workflowv2 internal http://{{ controller }}:8989/v2
        openstack endpoint create --region RegionOne workflowv2 admin http://{{ controller }}:8989/v2
    - unless: openstack user show mistral
    - env:
        mistral_pass: {{ passwords.mistral_pass }}
        OS_CLOUD: test

openstack-mistral-bootstrap-db:
  cmd.run:
    - name: |
        mistral-db-manage --config-file /etc/mistral/mistral.conf upgrade head
        mistral-db-manage --config-file /etc/mistral/mistral.conf populate
    - onchanges:
        - ini: openstack-mistral-initial-config
        - cmd: openstack-mistral-bootstrap

# for manual debugging
opensatck-mistral-admin-openrc:
  file.managed:
    - name: /root/admin_openrc
    - contents: |
        export OS_PROJECT_DOMAIN_NAME=Default
        export OS_USER_DOMAIN_NAME=Default
        export OS_PROJECT_NAME=service
        export OS_USERNAME=admin
        export OS_PASSWORD={{ passwords.admin_pass }}
        export OS_AUTH_URL=http://{{ controller }}:5000
        export OS_IDENTITY_API_VERSION=3
        export OS_IMAGE_API_VERSION=2
        export OS_VOLUME_API_VERSION=3

{% for service in [
  'mistral-api',
  'mistral-engine',
  'mistral-event-engine',
  'mistral-executor'] %}
openstack-mistral-service-{{ service }}:
  service.running:
    - name: {{ service }}
    - enable: True
{% endfor %}

#TODO: horizon dashboards are bad, they should go somewhere else
openstack-mistral-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        pip3 install mistral-dashboard
        cp /usr/local/lib/python3.6/dist-packages/mistraldashboard/enabled/_[1-9]*.py /usr/share/openstack-dashboard/openstack_dashboard/local/enabled/
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 /usr/share/openstack-dashboard/manage.py compress --force
        service apache2 restart
    - onchanges:
      - cmd: openstack-mistral-bootstrap-db
