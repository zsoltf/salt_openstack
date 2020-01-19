{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('nova', 'nova', passwords.nova_db_pass) }}
{{ create_database('nova_api', 'nova', passwords.nova_db_pass) }}
{{ create_database('nova_cell0', 'nova', passwords.nova_db_pass) }}
