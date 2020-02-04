{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('magnum', 'magnum', passwords.magnum_db_pass) }}
