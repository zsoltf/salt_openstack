{% from 'openstack/map.jinja' import admin_ip with context %}

{% set mine = salt['mine.get']('openstack:role:*', 'test.ping', 'grain') %}
{% set clients = [] %}
{% for node in mine %}
{% do clients.append(node ~ ':9100') %}
{% endfor %}

{% set ceph_mon_mine = salt['mine.get']('ceph:role:mon', 'test.ping', 'grain') %}
{% set ceph_clients = [] %}
{% for node in ceph_mon_mine %}
{% do ceph_clients.append(node ~ ':9283') %}
{% endfor %}

{% set ceph_mine = salt['mine.get']('ceph:role:*', 'test.ping', 'grain') %}
{% for node in ceph_mine %}
{% do clients.append(node ~ ':9100') %}
{% endfor %}

# elastic stack

openstack-monitor-elastic-repo:
  pkgrepo.managed:
    - humanname: Elastic
    - name: deb https://artifacts.elastic.co/packages/7.x/apt stable main
    - file: /etc/apt/sources.list.d/elastic-7.list
    - keyid: D88E42B4
    - keyserver: https://artifacts.elastic.co/GPG-KEY-elasticsearch

openstack-monitor-elasticsearch:
  pkg.installed:
    - name: elasticsearch
  file.managed:
    - name: /etc/elasticsearch/elasticsearch.yml
    - contents: |
        cluster.name: stack-monitor
        node.name: {{ grains['id'] }}
        node.attr.project: openstack
        path.data: /var/lib/elasticsearch
        path.logs: /var/log/elasticsearch
        network.host: {{ admin_ip }}
        http.port: 9200
        cluster.initial_master_nodes: ["{{ grains['id'] }}"]
  service.running:
    - name: elasticsearch
    - enable: True
    - watch:
      - file: openstack-monitor-elasticsearch
      - pkg: openstack-monitor-elasticsearch

openstack-monitor-kibana-log:
  file.managed:
    - name: /var/log/kibana/kibana.log
    - makedirs: True
    - replace: False
    - user: kibana

openstack-monitor-kibana:
  pkg.installed:
    - name: kibana
  file.managed:
    - name: /etc/kibana/kibana.yml
    - contents: |
        server.host: {{ admin_ip }}
        server.name: {{ grains['id'] }}
        elasticsearch.hosts: ["http://{{ grains['id'] }}:9200"]
        logging.dest: /var/log/kibana/kibana.log
  service.running:
    - name: kibana
    - enable: True
    - watch:
      - file: openstack-monitor-kibana
      - pkg: openstack-monitor-kibana

# grafana

openstack-monitor-grafana-repo:
  pkgrepo.managed:
    - humanname: Grafana
    - name: deb https://packages.grafana.com/oss/deb stable main
    - file: /etc/apt/sources.list.d/grafana-stable.list
    - keyid: '8C8C34C524098CB6'
    - keyserver: https://packages.grafana.com/gpg.key

openstack-monitor-grafana:
  pkg.installed:
    - name: grafana
  service.running:
    - name: grafana-server
    - enable: True
    - require:
      - pkg: openstack-monitor-grafana

# fluentd

openstack-monitor-fluentd:
  pkgrepo.managed:
    - humanname: Fluentd
    - name: deb http://packages.treasuredata.com/3/ubuntu/bionic/ bionic contrib
    - file: /etc/apt/sources.list.d/fluentd.list
    - keyid: '901F9177AB97ACBE'
    - keyserver: https://packages.treasuredata.com/GPG-KEY-td-agent
  file.managed:
    - name: /etc/td-agent/td-agent.conf
    - contents: |
        <system>
          log_level error
        </system>

        <source>
          @type forward
          bind 0.0.0.0
          port 24224
        </source>

        <filter openstack.*>
          @type record_transformer
          <record>
            app ${tag_parts[1]}
          </record>
        </filter>

        <filter openstack.apache>
          @type record_transformer
          enable_ruby
          <record>
            message ${record['host']} ${record['method']} ${record['path']} ${record['code']} ${record['size']}
          </record>
        </filter>

        <match **>
          @type elasticsearch
          host {{ grains['id'] }}
          port 9200
          logstash_format true
          logstash_prefix ${tag[0]}
          flush_interval 5
        </match>
  pkg.installed:
    - name: td-agent
  service.running:
    - name: td-agent
    - enable: True
    - watch:
      - pkg: openstack-monitor-fluentd
      - file: openstack-monitor-fluentd


# prometheus

openstack-monitor-prometheus:
  file.managed:
    - name: /etc/prometheus/prometheus.yml
    - makedirs: True
    - contents: |

        global:
          scrape_interval: 15s
          evaluation_interval: 15s
          external_labels:
              monitor: 'openstack'

        scrape_configs:

          - job_name: 'prometheus'
            scrape_interval: 5s
            scrape_timeout: 5s
            static_configs:
              - targets: ['localhost:9090']

          - job_name: node
            static_configs:
              - targets: {{ clients }}

          - job_name: ceph
            static_configs:
              - targets: {{ ceph_clients }}

  pkg.installed:
    - name: prometheus

  service.running:
    - name: prometheus
    - enable: True
    - watch:
      - file: openstack-monitor-prometheus

openstack-monitor-prometheus-alertmanager:
  pkg.installed:
    - name: prometheus-alertmanager
  service.running:
    - name: prometheus-alertmanager
    - enable: True
    - require:
      - pkg: openstack-monitor-prometheus-alertmanager
