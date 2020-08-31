{% from 'openstack/map.jinja' import admin_ip, database, mq, memcache, controller, passwords with context %}

openstack-kuryr-cni-user:
  cmd.run:
    - name: |
        groupadd --system kuryr
        useradd --home-dir "/var/lib/kuryr" --create-home --system --shell /bin/false -g kuryr kuryr
        mkdir -p /etc/kuryr
        chown kuryr:kuryr /etc/kuryr
        apt install -y python3-pip git
    - unless: id kuryr

openstack-kuryr-cni-components:
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
        - cmd: openstack-kuryr-cni-user

#TODO: remove hardcoded data
openstack-kuryr-cni-initial-config:
  ini.options_present:
    - name: /etc/kuryr/kuryr.conf
    - sections:
        DEFAULT:
          bindir: /usr/local/libexec/kuryr
        kubernetes:
          api_root: https://10.5.49.9
          ssl_client_crt_file: /data/certs/k8s-client.crt
          ssl_client_key_file: /data/certs/k8s-client.key
          ssl_ca_crt_file: /data/certs/k8s-ca.crt
          #vif_pool_driver
          #pod_vif_driver


openstack-kuryr-cni-service:
  service.running:
    - name: kuryr-cni
    - enable: True
    - require:
        - cmd: openstack-kuryr-cni-service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - file: openstack-kuryr-cni-service
  file.managed:
    - name: /etc/systemd/system/kuryr-cni.service
    - contents: |
        [Unit]
        Description = kuryr-cni

        [Service]
        ExecStart = /usr/local/bin/kuryr-daemon --config-file /etc/kuryr/kuryr.conf
        CapabilityBoundingSet = CAP_NET_ADMIN

        [Install]
        WantedBy = multi-user.target
