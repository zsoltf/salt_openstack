{% from 'openstack/map.jinja' import admin_ip, database, mq, memcache, controller, passwords with context %}

include:
  - .docker

openstack-kuryr-user:
  cmd.run:
    - name: |
        groupadd --system kuryr
        useradd --home-dir "/var/lib/kuryr" --create-home --system --shell /bin/false -g kuryr kuryr
        mkdir -p /etc/kuryr
        chown kuryr:kuryr /etc/kuryr
        apt install -y python3-pip git
    - unless: id kuryr

openstack-kuryr-components:
  cmd.run:
    - name: |
        cd /var/lib/kuryr
        git clone -b master https://git.openstack.org/openstack/kuryr-libnetwork.git
        chown -R kuryr:kuryr kuryr-libnetwork
        cd kuryr-libnetwork
        pip3 install -r requirements.txt
        python3 setup.py install
        su -s /bin/sh -c "./tools/generate_config_file_samples.sh" kuryr
        su -s /bin/sh -c "cp etc/kuryr.conf.sample /etc/kuryr/kuryr.conf" kuryr
    - onchanges:
        - cmd: openstack-kuryr-user

openstack-kuryr-initial-config:
  ini.options_present:
    - name: /etc/kuryr/kuryr.conf
    - sections:
        DEFAULT:
          bindir: /usr/local/libexec/kuryr
          capability_scope: global
          process_external_connectivity: 'False'
        neutron:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: kuryr
          password: {{ passwords.kuryr_pass }}

openstack-kuryr-service:
  service.running:
    - name: kuryr-libnetwork
    - enable: True
    - require:
        - cmd: openstack-kuryr-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-kuryr-service
  file.managed:
    - name: /etc/systemd/system/kuryr-libnetwork.service
    - contents: |
        [Unit]
        Description = Kuryr-libnetwork - Docker network plugin for Neutron

        [Service]
        ExecStart = /usr/local/bin/kuryr-server --config-file /etc/kuryr/kuryr.conf
        CapabilityBoundingSet = CAP_NET_ADMIN

        [Install]
        WantedBy = multi-user.target


openstack-zun-user:
  cmd.run:
    - name: |
        groupadd --system zun
        useradd --home-dir "/var/lib/zun" --create-home --system --shell /bin/false -g zun zun
        mkdir -p /etc/zun
        chown zun:zun /etc/zun
        apt install -y python3-pip git
    - unless: id zun

openstack-zun-components:
  cmd.run:
    - name: |
        cd /var/lib/zun
        git clone -b stable/train https://git.openstack.org/openstack/zun.git
        chown -R zun:zun zun
        cd zun
        pip3 install -r requirements.txt
        python3 setup.py install
        su -s /bin/sh -c "oslo-config-generator --config-file etc/zun/zun-config-generator.conf" zun
        su -s /bin/sh -c "cp etc/zun/zun.conf.sample /etc/zun/zun.conf" zun
        su -s /bin/sh -c "cp etc/zun/rootwrap.conf /etc/zun/rootwrap.conf" zun
        su -s /bin/sh -c "mkdir -p /etc/zun/rootwrap.d" zun
        su -s /bin/sh -c "cp etc/zun/rootwrap.d/* /etc/zun/rootwrap.d/" zun
    - onchanges:
        - cmd: openstack-zun-user

openstack-zun-sudoer:
  file.managed:
    - name: /etc/sudoers.d/zun_sudoers
    - contents: |
        zun ALL=(root) NOPASSWD: /usr/local/bin/zun-rootwrap /etc/zun/rootwrap.conf *

openstack-zun-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/zun/zun.conf
        sed -i /^$/d /etc/zun/zun.conf
    - onchanges:
      - cmd: openstack-zun-components

openstack-zun-initial-config:
  ini.options_present:
    - name: /etc/zun/zun.conf
    - sections:
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          state_path: /var/lib/zun
        database:
          connection: 'mysql+pymysql://zun:{{ passwords.zun_db_pass }}@{{ database }}/zun'
        keystone_auth:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: zun
          password: {{ passwords.zun_pass }}
          auth_version: v3
          auth_protocol: http
          service_token_roles_required: 'True'
          endpoint_type: internalURL
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: zun
          password: {{ passwords.zun_pass }}
        oslo_concurrency:
          lock_path: /var/lib/zun/tmp
        compute:
          host_shared_with_nova: 'true'


openstack-zun-docker-kuryr-service:
  service.running:
    - name: docker
    - enable: True
    - watch:
        - cmd: openstack-zun-docker-kuryr-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-zun-docker-kuryr-service
  file.managed:
    - name: /etc/systemd/system/docker.service.d/docker.conf
    - makedirs: True
    - contents: |
        [Service]
        ExecStart=
        ExecStart=/usr/bin/dockerd --group zun -H tcp://{{ grains['id'] }}:2375 -H unix:///var/run/docker.sock --cluster-store etcd://{{ controller }}:2379

openstack-zun-compute-service:
  service.running:
    - name: zun-compute
    - enable: True
    - require:
        - cmd: openstack-zun-compute-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-zun-compute-service
  file.managed:
    - name: /etc/systemd/system/zun-compute.service
    - contents: |
        [Unit]
        Description = OpenStack Container Service Compute Agent

        [Service]
        ExecStart = /usr/local/bin/zun-compute
        User = zun

        [Install]
        WantedBy = multi-user.target
