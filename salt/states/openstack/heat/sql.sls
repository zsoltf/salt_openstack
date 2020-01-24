{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('heat', 'heat', passwords.heat_db_pass) }}
