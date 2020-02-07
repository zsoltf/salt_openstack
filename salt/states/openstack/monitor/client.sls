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

# prometheus

openstack-monitor-prometheus-node-exporter:
  pkg.installed:
    - name: prometheus-node-exporter
  ini.options_present:
    - name: /lib/systemd/system/prometheus-node-exporter.service
    - sections:
        Service:
          User: root
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
        - ini: openstack-monitor-prometheus-node-exporter
  service.running:
    - name: prometheus-node-exporter
    - enable: True
    - require:
      - pkg: openstack-monitor-prometheus-node-exporter
      - ini: openstack-monitor-prometheus-node-exporter
