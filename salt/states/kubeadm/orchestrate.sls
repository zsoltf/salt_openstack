{% set domain = salt['grains.get']('datacenter', 'openstack') ~ '.internal' %}

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

### install control plane ###

install-kubeadm-on-control-plane:
  salt.state:
    - tgt: 'kube:role:master'
    - tgt_type: grain
    - sls:
        - kubeadm

bootstrap-first-control-plane:
  salt.state:
    - tgt: 'G@kube:role:master and G@kube:first_master'
    - tgt_type: compound
    - sls: kubeadm.master.bootstrap
    - require:
        - salt: install-kubeadm-on-control-plane
        - salt: generate-etcd-certs

join-control-planes:
  salt.state:
    - tgt: 'G@kube:role:master and not G@kube:first_master'
    - tgt_type: compound
    - sls: kubeadm.master.join
    - require:
        - salt: bootstrap-first-control-plane

### install workers ###

install-kubeadm-on-workers:
  salt.state:
    - tgt: 'kube:role:worker'
    - tgt_type: grain
    - sls:
        - kubeadm
    - require:
        - salt: join-control-planes

join-workers:
  salt.state:
    - tgt: 'kube:role:worker'
    - tgt_type: grain
    - sls:
        - kubeadm.worker
    - require:
        - salt: install-kubeadm-on-workers
