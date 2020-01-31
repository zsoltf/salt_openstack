{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('zun', 'zun', passwords.zun_db_pass) }}
