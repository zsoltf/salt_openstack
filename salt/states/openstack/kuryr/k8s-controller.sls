{% from 'openstack/map.jinja' import admin_ip, database, mq, memcache, controller, passwords with context %}

openstack-kuryr-kubernetes-user:
  cmd.run:
    - name: |
        groupadd --system kuryr
        useradd --home-dir "/var/lib/kuryr" --create-home --system --shell /bin/false -g kuryr kuryr
        mkdir -p /etc/kuryr
        chown kuryr:kuryr /etc/kuryr
        apt install -y python3-pip git
    - unless: id kuryr

openstack-kuryr-kubernetes-components:
  cmd.run:
    - name: |
        cd /var/lib/kuryr
        git clone -b stable/ussuri https://git.openstack.org/openstack/kuryr-kubernetes.git
        chown -R kuryr:kuryr kuryr-kubernetes
        cd kuryr-kubernetes
        pip3 install -r requirements.txt
        python3 setup.py install
        su -s /bin/sh -c "./tools/generate_config_file_samples.sh" kuryr
        su -s /bin/sh -c "cp etc/kuryr.conf.sample /etc/kuryr/kuryr.conf" kuryr
    - onchanges:
        - cmd: openstack-kuryr-kubernetes-user

#TODO: remove hardcoded data
openstack-kuryr-kubernetes-initial-config:
  ini.options_present:
    - name: /etc/kuryr/kuryr.conf
    - sections:
        DEFAULT:
          bindir: /usr/local/libexec/kuryr
          #capability_scope: global
          #process_external_connectivity: 'False'
        kubernetes:
          api_root: https://10.5.49.9
          ssl_client_crt_file: /data/certs/k8s-client.crt
          ssl_client_key_file: /data/certs/k8s-client.key
          ssl_ca_crt_file: /data/certs/k8s-ca.crt
          #vif_pool_driver
          #pod_vif_driver
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
        neutron_defaults:
          #ovs_bridge: br-int
          service_subnet: cc7bf243-4a30-4eaf-83d2-d67ab5a5371f
          pod_security_groups: 2b5d2742-ff77-430c-999e-7dd87b8c3d0a
          pod_subnet: cd404754-39ca-49c1-9751-c3fb98c881e4
          project: 8125285e80cf40f3814035b709de4e9e
          external_svc_net: 929cb5bd-7d0c-4e43-80bb-0b8a9aecffac


openstack-kuryr-kubernetes-service:
  service.running:
    - name: kuryr-k8s-controller
    - enable: True
    - require:
        - cmd: openstack-kuryr-kubernetes-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-kuryr-kubernetes-service
  file.managed:
    - name: /etc/systemd/system/kuryr-k8s-controller.service
    - contents: |
        [Unit]
        Description = Kuryr-Kubernetes

        [Service]
        ExecStart = /usr/local/bin/kuryr-k8s-controller --config-file /etc/kuryr/kuryr.conf
        CapabilityBoundingSet = CAP_NET_ADMIN

        [Install]
        WantedBy = multi-user.target
