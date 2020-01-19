{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('cinder', 'cinder', passwords.cinder_db_pass) }}
