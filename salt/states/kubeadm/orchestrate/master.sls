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

join-control-planes:
  salt.state:
    - tgt: 'G@kube:role:master and not G@kube:first_master'
    - tgt_type: compound
    - sls: kubeadm.master.join
    - require:
        - salt: bootstrap-first-control-plane
