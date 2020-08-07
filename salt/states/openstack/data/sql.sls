{% from 'openstack/map.jinja' import admin_ip, passwords with context %}

# db
openstack-mysql:

  pkg.installed:
    - names:
        - mysql-server
        - python3-pymysql

  file.managed:
    - name: /etc/mysql/mysql.conf.d/openstack.cnf
    - contents: |
        [mysqld]
        bind-address = {{ admin_ip }}

        default-storage-engine = innodb
        innodb_file_per_table = on
        max_connections = 4096
        collation-server = utf8_general_ci
        character-set-server = utf8

  service.running:
    - name: mysql
    - enable: True
    - watch:
        - pkg: openstack-mysql
        - file: openstack-mysql

openstack-mysql-salt:

  pkg.installed:
    - name: python3-mysqldb

  file.managed:
    - name: /etc/salt/minion.d/mysql.conf
    - contents: |
        mysql.host: 'localhost'
        mysql.port: 3306
        mysql.user: 'root'
        mysql.unix_socket: '/var/run/mysqld/mysqld.sock'
        mysql.db: 'mysql'
        mysql.charset: 'utf8'


openstack-sql-root:

  mysql_user.present:
    - name: root
    - password: {{ passwords.mysql_root_db_pass }}
    - host: '%'

  mysql_grants.present:
    - user: root
    - grant: all privileges
    - database: root.*
    - host: '%'
    - require:
        - file: openstack-mysql-salt
        - service: openstack-mysql
