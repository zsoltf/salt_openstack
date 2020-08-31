### install etcd ###

install-kubeadm-on-etcd:
  salt.state:
    - tgt: 'kube:role:etcd'
    - tgt_type: grain
    - sls: kubeadm

install-etcd-service:
  salt.state:
    - tgt: 'kube:role:etcd'
    - tgt_type: grain
    - sls: kubeadm.etcd.service
    - require:
        - salt: install-kubeadm-on-etcd

generate-etcd-certs:
  salt.state:
    - tgt: 'G@kube:role:etcd and G@kube:first_etcd'
    - tgt_type: compound
    - sls: kubeadm.etcd.bootstrap
    - require:
        - salt: install-etcd-service

deploy-etcd-configs:
  salt.state:
    - tgt: 'kube:role:etcd'
    - tgt_type: grain
    - sls: kubeadm.etcd.config
    - require:
        - salt: generate-etcd-certs
