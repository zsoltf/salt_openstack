#TODO: manage this some other way...
ceph-monitor-prometheus:
  file.append:
    - name: /etc/prometheus/prometheus.yml
    - makedirs: True
    - text: |
      - job_name: ceph
        static_configs:
          - targets: {{ clients }}
