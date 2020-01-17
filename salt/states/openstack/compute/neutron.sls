{% set neutron_pass = salt['pillar.get']('openstack:passwords:neutron_pass') %}
{% set metadata_pass = salt['pillar.get']('openstack:passwords:metadata_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') | dictsort() | first %}
{% set rabbit_pass = salt['pillar.get']('openstack:passwords:rabbit_pass') %}

{% set provider_interface = salt['pillar.get']('openstack:provider_interface') %}

{% set overlay_network = salt['pillar.get']('openstack:overlay_network') %}
{% set overlay_interface_ip = [] %}
# maybe try ip_addrs with cidr arg
{% for ip in salt['network.ip_addrs']() if salt['network.ip_in_subnet'](ip, overlay_network) %}
  {% do overlay_interface_ip.append(ip) %}
{% endfor %}
{% set overlay_interface_ip = overlay_interface_ip|first %}

openstack-neutron:
  pkg.installed:
    - name: neutron-linuxbridge-agent

openstack-neutron-nova-config:
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

openstack-neutron-compute-config:
  ini.options_present:
    - name: /etc/neutron/neutron.conf
    - sections:
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
        oslo_concurrency:
          lock_path: /var/lib/neutron/tmp

openstack-neutron-compute-linuxbridge-config:
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

openstack-neutron-service:
  service.running:
    - name: neutron-linuxbridge-agent
    - enable: True
    - watch:
        - ini: openstack-neutron-compute-config
        - ini: openstack-neutron-nova-config
        - ini: openstack-neutron-compute-linuxbridge-config
