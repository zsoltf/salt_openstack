{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('octavia', 'octavia', passwords.octavia_db_pass) }}
