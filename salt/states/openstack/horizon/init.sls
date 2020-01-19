{% from 'openstack/map.jinja' import controller, memcache with context %}

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
    - repl: '{{ memcache }}:11211'

openstack-dashboard-config-4:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - append_if_not_found: True
    - pattern: ^DEFAULT_THEME = .*
    - repl: DEFAULT_THEME = 'default'

openstack-dashboard-service:
  service.running:
    - name: apache2
    - watch:
      - file: openstack-dashboard-config-1
      - file: openstack-dashboard-config-2
      - file: openstack-dashboard-config-3
      - file: openstack-dashboard-config-4
