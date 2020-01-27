{% from 'openstack/map.jinja' import admin_ip, monitor with context %}

# fluentd

openstack-monitor-fluent-bit:
  pkgrepo.managed:
    - humanname: Fluent Bit
    - name: deb https://packages.fluentbit.io/ubuntu/bionic bionic main
    - file: /etc/apt/sources.list.d/fluent-bit.list
    - keyid: '4FF8368B6EA0722A'
    - keyserver: https://packages.fluentbit.io/fluentbit.key
  pkg.installed:
    - name: td-agent-bit
  service.running:
    - name: td-agent-bit
    - enable: True
    - watch:
      - pkg: openstack-monitor-fluent-bit
      - file: openstack-monitor-fluent-bit-config

openstack-monitor-fluent-bit-config:
  file.managed:
    - name: /etc/td-agent-bit/td-agent-bit.conf
    - defaults:
        monitor: {{ monitor }}
    - source: salt://openstack/monitor/td-agent-bit.conf.jinja
    - template: jinja
    - require:
      - file: openstack-monitor-fluent-bit-parsers

openstack-monitor-fluent-bit-parsers:
  file.managed:
    - name: /etc/td-agent-bit/openstack_parsers.conf
    - source: salt://openstack/monitor/openstack_parsers.conf

# beats

openstack-monitor-metricbeat-log:
  file.managed:
    - name: /var/log/metricbeat/metricbeat.log
    - makedirs: True
    - replace: False

openstack-monitor-client-metricbeat:
  pkgrepo.managed:
    - humanname: Elastic
    - name: deb https://artifacts.elastic.co/packages/7.x/apt stable main
    - file: /etc/apt/sources.list.d/elastic-7.list
    - keyid: D88E42B4
    - keyserver: https://artifacts.elastic.co/GPG-KEY-elasticsearch
  pkg.installed:
    - name: metricbeat
    - require:
      - pkgrepo: openstack-monitor-client-metricbeat
  file.managed:
    - name: /etc/metricbeat/metricbeat.yml
    - contents: |
        logging.level: error
        metricbeat.config.modules:
          path: ${path.config}/modules.d/*.yml
          reload.enabled: false
        setup.template.settings:
          index.number_of_shards: 1
          index.codec: best_compression
        setup.kibana:
          host: "{{ monitor }}:5601"
        output.elasticsearch:
          hosts: ["{{ monitor }}:9200"]
        processors:
          - add_host_metadata: ~
          - add_cloud_metadata: ~
          - add_docker_metadata: ~
          - add_kubernetes_metadata: ~
    - require:
      - pkg: openstack-monitor-client-metricbeat
  service.running:
    - name: metricbeat
    - enable: True
    - watch:
      - pkg: openstack-monitor-client-metricbeat
      - file: openstack-monitor-client-metricbeat

# prometheus

openstack-monitor-prometheus-node-exporter:
  pkg.installed:
    - name: prometheus-node-exporter
  service.running:
    - name: prometheus-node-exporter
    - enable: True
    - require:
      - pkg: openstack-monitor-prometheus-node-exporter
