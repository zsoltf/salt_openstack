{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('neutron', 'neutron', passwords.neutron_db_pass) }}
