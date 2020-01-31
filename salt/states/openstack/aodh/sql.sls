{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('aodh', 'aodh', passwords.aodh_db_pass) }}
