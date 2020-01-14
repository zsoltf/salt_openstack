{% set neutron_pass = salt['pillar.get']('openstack:passwords:neutron_pass') %}
{% set metadata_pass = salt['pillar.get']('openstack:passwords:metadata_pass') %}
{% set controller, ips = salt['mine.get']('openstack:role:controller', 'ip', 'grain') | dictsort() | first %}

openstack-neutron-compute-config:
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
