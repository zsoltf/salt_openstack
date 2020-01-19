{% from 'openstack/map.jinja' import database, memcache, controller, passwords with context %}
{% set glance_host = grains['id'] %}

openstack-glance:
  pkg.installed:
    - name: glance

openstack-glance-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/glance/glance-api.conf
        sed -i /^$/d /etc/glance/glance-api.conf
    - onchanges:
      - pkg: openstack-glance

openstack-glance-initial-config:
  ini.options_present:
    - name: /etc/glance/glance-api.conf
    - sections:
        database:
          connection: 'mysql+pymysql://glance:{{ passwords.glance_db_pass }}@{{ database }}/glance'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: glance
          password: {{ passwords.glance_pass }}
        paste_deploy:
          flavor: keystone
        glance_store:
          stores: file,http
          default_store: file
          filesystem_store_datadir: /var/lib/glance/images

openstack-glance-bootstrap-db:
  cmd.run:
    - name: |
        glance-manage db sync && \
        service glance-api restart
    - onchanges:
        - ini: openstack-glance-initial-config

# create glance user, role, service and endpoint
# note: keystone state sets up auth for openstack command
# TODO: use native salt states
openstack-glance-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $glance_pass glance
        openstack role add --project service --user glance admin
        openstack service create --name glance --description "OpenStack Image" image
        openstack endpoint create --region RegionOne image public http://{{ controller }}:9292
        openstack endpoint create --region RegionOne image internal http://{{ controller }}:9292
        openstack endpoint create --region RegionOne image admin http://{{ controller }}:9292
    - unless: openstack user show glance
    - env:
        glance_pass: {{ passwords.glance_pass }}
        OS_CLOUD: test

# set up a cirros image
openstack-glance-cirros-image:
  cmd.run:
    - name: |
        wget -q http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img && \
        openstack image create --file cirros-0.4.0-x86_64-disk.img \
          --disk-format qcow2 --container-format bare --public \
          cirros
    - creates: /root/cirros-0.4.0-x86_64-disk.img
    - cwd: /root
    - env:
        OS_CLOUD: test
