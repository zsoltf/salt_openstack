{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('vitrage', 'vitrage', passwords.vitrage_db_pass) }}
