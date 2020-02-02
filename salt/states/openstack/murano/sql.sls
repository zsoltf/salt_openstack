{% from 'openstack/map.jinja' import create_database, passwords with context %}

{{ create_database('murano', 'murano', passwords.murano_db_pass) }}
