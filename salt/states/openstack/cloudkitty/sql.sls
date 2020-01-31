{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('cloudkitty', 'cloudkitty', passwords.cloudkitty_db_pass) }}
