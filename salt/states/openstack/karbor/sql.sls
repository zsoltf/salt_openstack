{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('karbor', 'karbor', passwords.karbor_db_pass) }}
