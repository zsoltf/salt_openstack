{% from 'openstack/map.jinja' import admin_ip with context %}

# memcached
openstack-memcache:

  pkg.installed:
    - names:
        - memcached
        - python3-memcache

  file.replace:
    - name: /etc/memcached.conf
    - backup: True
    - pattern: -l 127.*
    - repl: -l {{ admin_ip }}

  service.running:
    - name: memcached
    - enable: True
    - watch:
        - pkg: openstack-memcache
        - file: openstack-memcache
