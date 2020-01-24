{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('barbican', 'barbican', passwords.barbican_db_pass) }}
