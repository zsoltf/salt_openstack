{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('mistral', 'mistral', passwords.mistral_db_pass) }}
