{% set neutron_pass = salt['pillar.get']('openstack:passwords:neutron_pass') %}
#HACK
{% set database = "mysql-s3" %}
{% set neutron_db_pass = salt['pillar.get']('openstack:passwords:neutron_db_pass') %}
{% set nova_pass = salt['pillar.get']('openstack:passwords:nova_pass') %}
{% set rabbit_pass = salt['pillar.get']('openstack:passwords:rabbit_pass') %}
{% set metadata_pass = salt['pillar.get']('openstack:passwords:metadata_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') | dictsort() | first %}
{% set controller_ip = ips|first %}

{% set provider_interface = salt['pillar.get']('openstack:provider_interface') %}

{% set overlay_network = salt['pillar.get']('openstack:overlay_network') %}
{% set overlay_interface_ip = [] %}
# maybe try ip_addrs with cidr arg
{% for ip in salt['network.ip_addrs']() if salt['network.ip_in_subnet'](ip, overlay_network) %}
  {% do overlay_interface_ip.append(ip) %}
{% endfor %}
{% set overlay_interface_ip = overlay_interface_ip|first %}

openstack-neutron-db:

  mysql_database.present:
    - name: neutron

  mysql_user.present:
    - name: neutron
    - password: {{ neutron_db_pass }}
    - host: '%'

  mysql_grants.present:
    - user: neutron
    - grant: all privileges
    - database: neutron.*
    - host: '%'
    - require:
        - mysql_database: openstack-neutron-db
        - mysql_user: openstack-neutron-db

openstack-neutron:
  pkg.installed:
    - pkgs:
      - neutron-server
      - neutron-plugin-ml2
      - neutron-linuxbridge-agent
      - neutron-l3-agent
      - neutron-dhcp-agent
      - neutron-metadata-agent

openstack-neutron-clear-comments:
  cmd.run:
    - name: |
        sed -i /^#/d /etc/neutron/neutron.conf
        sed -i /^$/d /etc/neutron/neutron.conf
    - onchanges:
      - pkg: openstack-neutron

openstack-neutron-initial-config:
  ini.options_present:
    - name: /etc/neutron/neutron.conf
    - sections:
        database:
          connection: 'mysql+pymysql://neutron:{{ neutron_db_pass }}@{{ database }}/neutron'
        keystone_authtoken:
          www_authenticate_uri: http://{{ controller }}:5000
          auth_url: http://{{ controller }}:5000
          memcached_servers: {{ controller }}:11211
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          project_name: service
          username: neutron
          password: {{ neutron_pass }}
        DEFAULT:
          auth_strategy: keystone
          transport_url: rabbit://openstack:{{ rabbit_pass }}@{{ controller }}
          core_plugin: ml2
          service_plugins: router
          allow_overlapping_ips: 'true'
          notify_nova_on_port_status_changes: 'true'
          notify_nova_on_port_data_changes: 'true'
        nova:
          auth_url: http://{{ controller }}:5000
          auth_type: password
          project_domain_name: Default
          user_domain_name: Default
          region_name: RegionOne
          project_name: service
          username: nova
          password: {{ nova_pass }}
        oslo_concurrency:
          lock_path: /var/lib/neutron/tmp

openstack-neutron-ml2-config:
  ini.options_present:
    - name: /etc/neutron/plugins/ml2/ml2_conf.ini
    - sections:
        ml2:
          type_drivers: flat,vlan,vxlan
          tenant_network_types: vxlan
          mechanism_drivers: linuxbridge,l2population
          extension_drivers: port_sercurity
        ml2_type_flat:
          flat_networks: provider
        ml2_type_vxlan:
          vni_ranges: '1:1000'
        securitygroup:
          enable_ipset: 'true'

openstack-neutron-linuxbridge-config:
  ini.options_present:
    - name: /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    - sections:
        linux_bridge:
          physical_interface_mappings: 'provider:{{ provider_interface }}'
        vxlan:
          enable_vxlan: 'true'
          local_ip: {{ overlay_interface_ip }}
          l2_population: 'true'
        securitygroup:
          enable_security_group: 'true'
          firewall_driver: 'neutron.agent.linux.iptables_firewall.IptablesFirewallDriver'

openstack-neutron-br_netfilter:
  kmod.present:
    - name: br_netfilter

openstack-neutron-l3-config:
  ini.options_present:
    - name: /etc/neutron/l3_agent.ini
    - sections:
        DEFAULT:
          interface_driver: linuxbridge

openstack-neutron-dhcp-config:
  ini.options_present:
    - name: /etc/neutron/dhcp_agent.ini
    - sections:
        DEFAULT:
          interface_driver: linuxbridge
          dhcp_driver: neutron.agent.linux.dhcp.Dnsmasq
          enable_isolated_metadata: 'true'

openstack-neutron-metadata-config:
  ini.options_present:
    - name: /etc/neutron/metadata_agent.ini
    - sections:
        DEFAULT:
          nova_metadata_host: {{ controller }}
          metadata_proxy_shared_secret: {{ metadata_pass }}

openstack-neutron-nova-config-controller:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        neutron:
          auth_url: http://{{ controller }}:5000
          auth_type: password
          project_domain_name: default
          user_domain_name: default
          region_name: RegionOne
          project_name: service
          username: neutron
          password: {{ neutron_pass }}
          service_metadata_proxy: true
          metadata_proxy_shared_secret: {{ metadata_pass }}

# TODO: use native salt state
openstack-neutron-bootstrap:
  cmd.run:
    - name: |
        openstack user create --domain default --password $neutron_pass neutron
        openstack role add --project service --user neutron admin
        openstack service create --name neutron --description "OpenStack Networking" network
        openstack endpoint create --region RegionOne network public http://{{ controller }}:9696
        openstack endpoint create --region RegionOne network internal http://{{ controller }}:9696
        openstack endpoint create --region RegionOne network admin http://{{ controller }}:9696
    - unless: openstack user show neutron
    - env:
        neutron_pass: {{ neutron_pass }}
        OS_CLOUD: test

openstack-neutron-finalize:
  cmd.run:
    - name: |
        neutron-db-manage --config-file /etc/neutron/neutron.conf \
          --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head
        service nova-api restart
        service neutron-server restart
        service neutron-linuxbridge-agent restart
        service neutron-dhcp-agent restart
        service neutron-metadata-agent restart
        service neutron-l3-agent restart
    - env:
        OS_CLOUD: test
    - onchanges:
      - cmd: openstack-neutron-bootstrap
