{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('watcher', 'watcher', passwords.watcher_db_pass) }}
