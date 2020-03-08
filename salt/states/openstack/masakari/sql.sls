{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('masakari', 'masakari', passwords.masakari_db_pass) }}
