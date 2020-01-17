{% set controllers = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') %}
{% load_yaml as ntp_servers_map %}

default: {{ controllers|yaml }}

controller:
  - ntp.ubuntu.com
  - 0.ubuntu.pool.ntp.org
  - 1.ubuntu.pool.ntp.org
  - 2.ubuntu.pool.ntp.org

{% endload %}
{% set ntp_servers = salt['grains.filter_by'](ntp_servers_map, grain='openstack:role', default='default') %}

openstack-ntp:
  pkg.installed:
    - name: chrony

{% if ntp_servers %}
openstack-ntp-config:
  file.managed:
    - name: /etc/chrony/chrony.conf
    - watch_in:
        - service: openstack-ntp-service
    - contents: |
        {%- for ntp in ntp_servers %}
        pool {{ ntp }} iburst
        {%- endfor %}

        keyfile /etc/chrony/chrony.keys
        driftfile /var/lib/chrony/chrony.drift
        #log tracking measurements statistics
        logdir /var/log/chrony
        maxupdateskew 100.0
        rtcsync
        makestep 1 3
        allow 10.0.0.0/24
{% endif %}

openstack-ntp-service:
  service.running:
    - name: chrony
    - enable: True
    - watch:
        - pkg: openstack-ntp
