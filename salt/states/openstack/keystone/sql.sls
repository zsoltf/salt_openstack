{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('keystone', 'keystone', passwords.keystone_db_pass) }}
