{% from 'openstack/map.jinja' import ceph_client_cinder_key, ceph_secret_uuid, admin_ip, controller, memcache, mq, passwords with context %}
{% set nova_host = grains['id'] %}

openstack-nova-compute:
  pkg.installed:
    - name: nova-compute

openstack-nova-ceph-packages:
  pkg.installed:
    - names:
        - ceph-common
        - python3-rbd

openstack-nova-compute-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/nova/nova.conf
        sed -i /^$/d /etc/nova/nova.conf
    - onchanges:
      - pkg: openstack-nova-compute

openstack-nova-compute-nova-config:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        api:
          auth_strategy: keystone
        DEFAULT:
          transport_url: rabbit://openstack:{{ passwords.rabbit_pass }}@{{ mq }}:5672/
          my_ip: {{ admin_ip }}
          use_neutron: 'true'
          firewall_driver: 'nova.virt.firewall.NoopFirewallDriver'
          log_dir: ''
        glance:
          api_servers: http://{{ controller }}:9292
        oslo_concurrency:
          lock_path: /var/lib/nova/tmp
        placement:
          region_name: RegionOne
          project_domain_name: Default
          project_name: service
          auth_type: password
          user_domain_name: Default
          auth_url: http://{{ controller }}:5000/v3
          username: placement
          password: {{ passwords.placement_pass }}
        keystone_authtoken:
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ memcache }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: nova
          password: {{ passwords.nova_pass }}
        vnc:
          enabled: 'true'
          server_listen: '0.0.0.0'
          server_proxyclient_address: '$my_ip'
          nonvncproxy_base_url: http://{{ controller }}:6080/vnc_auto.html

openstack-nova-compute-initial-config:
  ini.options_present:
    - name: /etc/nova/nova-compute.conf
    - sections:
        libvirt:
          virt_type: qemu
          rbd_user: cinder
          rbd_secret_uuid: {{ ceph_secret_uuid }}

openstack-nova-ceph-secret-xml:
  cmd.run:
    - name: |
        echo {{ ceph_client_cinder_key }} > cinder.keyring
        cat > secret.xml <<EOF
        <secret ephemeral='no' private='no'>
          <uuid>{{ ceph_secret_uuid }}</uuid>
            <usage type='ceph'>
              <name>client.cinder secret</name>
            </usage>
          </secret>
        EOF
        virsh secret-define --file secret.xml
        sudo virsh secret-set-value --secret {{ ceph_secret_uuid }} --base64 $(cat cinder.keyring)
        rm cinder.keyring secret.xml
    - unless: virsh secret-list | grep {{ ceph_secret_uuid }}

openstack-nova-compute-service:
  service.running:
    - name: nova-compute
    - watch:
      - ini: openstack-nova-compute-initial-config
      - ini: openstack-nova-compute-nova-config