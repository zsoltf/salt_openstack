{% set domain = salt['grains.get']('datacenter', 'openstack') ~ '.internal' %}

openstack-cluster-wait:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - id_list:
        - kube-etcd-0.{{ domain }}
        - kube-etcd-1.{{ domain }}
        - kube-etcd-2.{{ domain }}
        - kube-master-0.{{ domain }}
        - kube-master-1.{{ domain }}
        - kube-master-2.{{ domain }}
        - kube-worker-0.{{ domain }}
        - kube-worker-1.{{ domain }}
        - kube-worker-2.{{ domain }}

mine-update:
  salt.function:
    - name: mine.update
    - tgt: '*'
    - require:
        - salt: openstack-cluster-wait
