{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('placement', 'placement', passwords.placement_db_pass) }}

