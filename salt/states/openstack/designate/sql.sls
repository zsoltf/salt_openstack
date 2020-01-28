{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('designate', 'designate', passwords.designate_db_pass) }}
