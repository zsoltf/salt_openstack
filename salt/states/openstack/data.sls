# configures the databases needed for a single control plane, no HA
# installs etcd, mysql, memcached and rabbitmq

{% set controller, ips = salt['mine.get']('openstack:role:controller', 'admin_network', 'grain') | dictsort() | first %}
{% set admin_network = salt['pillar.get']('openstack:admin_network') %}

{% set controller_ip = [] %}
{% for ip in ips if salt['network.ip_in_subnet'](ip, admin_network) %}
  {% do controller_ip.append(ip) %}
{% endfor %}
{% set controller_ip = controller_ip|first %}

# etcd
openstack-etcd:

  pkg.installed:
    - name: etcd

  file.managed:
    - name: /etc/default/etcd
    - contents: |
        ETCD_NAME="controller"
        ETCD_DATA_DIR="/var/lib/etcd"
        ETCD_INITIAL_CLUSTER_STATE="new"
        ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
        ETCD_INITIAL_CLUSTER="controller=http://{{ controller_ip }}:2380"
        ETCD_INITIAL_ADVERTISE_PEER_URLS="http://{{ controller_ip }}:2380"
        ETCD_ADVERTISE_CLIENT_URLS="http://{{ controller_ip }}:2379"
        ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
        ETCD_LISTEN_CLIENT_URLS="http://{{ controller_ip }}:2379"

  service.running:
    - name: etcd
    - enable: True
    - watch:
        - pkg: openstack-etcd
        - file: openstack-etcd


# db
#openstack-mysql:
#
#  pkg.installed:
#    - names:
#        - mysql-server
#        - python-pymysql
#
#  file.managed:
#    - name: /etc/mysql/mysql.conf.d/99-openstack.cnf
#    - contents: |
#        [mysqld]
#        bind-address = {{ controller_ip }}
#
#        default-storage-engine = innodb
#        innodb_file_per_table = on
#        max_connections = 4096
#        collation-server = utf8_general_ci
#        character-set-server = utf8
#
#  service.running:
#    - name: mysql
#    - enable: True
#    - watch:
#        - pkg: openstack-mysql
#        - file: openstack-mysql

  #cmd.run:
  #  - name: |
  #      mysql -uroot << 'EOF'
  #      UPDATE mysql.user SET Password=PASSWORD('$mysql_root_db_pass') WHERE User='root';
  #      DELETE FROM mysql.user WHERE user='root' AND host NOT IN ('localhost', '127.0.0.1', '::1');
  #      DELETE FROM mysql.user WHERE user='';
  #      FLUSH PRIVILEGES;
  #      EOF
  #  - env: {# salt['pillar.get']('openstack:passwords') #}
  #  - onchanges:
  #      - service: openstack-mysql

openstack-mysql-salt:

  pkg.installed:
    - name: python3-mysqldb

  #file.managed:
  #  - name: /etc/salt/minion.d/mysql.conf
  #  - contents: |
  #      mysql.host: 'localhost'
  #      mysql.port: 3306
  #      mysql.user: 'root'
  #      mysql.pass: '{{ salt['pillar.get']('openstack:passwords:mysql_root_db_pass') }}'
  #      mysql.db: 'mysql'
  #      mysql.charset: 'utf8'


# memcached
openstack-memcache:

  pkg.installed:
    - names:
        - memcached
        - python-memcache

  file.replace:
    - name: /etc/memcached.conf
    - backup: True
    - pattern: -l 127.*
    - repl: -l {{ controller_ip }}

  service.running:
    - name: memcached
    - enable: True
    - watch:
        - pkg: openstack-memcache
        - file: openstack-memcache


# mq
openstack-message-queue:

  pkg.installed:
    - name: rabbitmq-server

  cmd.run:
    - name: |
        rabbitmqctl add_user openstack $rabbit_pass
        rabbitmqctl set_permissions openstack ".*" ".*" ".*"
    - env: {{ salt['pillar.get']('openstack:passwords') }}
    - onchanges:
        - pkg: openstack-message-queue

  service.running:
    - name: rabbitmq-server
    - enable: True
    - watch:
        - pkg: openstack-message-queue
        - cmd: openstack-message-queue
