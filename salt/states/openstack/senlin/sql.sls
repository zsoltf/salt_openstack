{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('senlin', 'senlin', passwords.senlin_db_pass) }}
