{% set controller, ips = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') | dictsort() | first %}

openstack-dashboard:
  pkg.installed:
    - pkgs:
      - openstack-dashboard
      - fonts-roboto

# minimal config

openstack-dashboard-config-1:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - pattern: ^OPENSTACK_HOST = .*
    - repl: OPENSTACK_HOST = '{{ controller }}'

openstack-dashboard-config-2:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - append_if_not_found: True
    - pattern: ^SESSION_ENGINE = .*
    - repl: SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

openstack-dashboard-config-3:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - pattern: '127.0.0.1:11211'
    - repl: '{{ controller }}:11211'

openstack-dashboard-config-4:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - append_if_not_found: True
    - pattern: ^DEFAULT_THEME = .*
    - repl: DEFAULT_THEME = 'default'
