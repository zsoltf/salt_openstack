{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('gnocchi', 'gnocchi', passwords.gnocchi_db_pass) }}
