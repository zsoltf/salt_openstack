{% from 'openstack/map.jinja' import admin_ip with context %}

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
        ETCD_INITIAL_CLUSTER="controller=http://{{ admin_ip }}:2380"
        ETCD_INITIAL_ADVERTISE_PEER_URLS="http://{{ admin_ip }}:2380"
        ETCD_ADVERTISE_CLIENT_URLS="http://{{ admin_ip }}:2379"
        ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
        ETCD_LISTEN_CLIENT_URLS="http://{{ admin_ip }}:2379"

  service.running:
    - name: etcd
    - enable: True
    - watch:
        - pkg: openstack-etcd
        - file: openstack-etcd
