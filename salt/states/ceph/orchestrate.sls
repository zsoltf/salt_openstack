prepare-ceph-network:
  salt.state:
    - tgt: 'ceph:role'
    - tgt_type: grain
    - sls:
        - ceph.network

install-ceph-deploy:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls:
        - ceph.deploy.bootstrap

prepare-ceph-nodes:
  salt.state:
    - tgt: 'ceph:role'
    - tgt_type: grain
    - sls:
        - ceph.node

install-ceph-mgr-modules:
  salt.state:
    - tgt: 'ceph:role:mon'
    - tgt_type: grain
    - sls:
        - ceph.mgr

init-ceph-cluster:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls:
        - ceph.deploy
    - require:
        - salt: prepare-ceph-nodes

ceph-deploy-mon:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls: ceph.deploy.mon
    - require:
        - salt: init-ceph-cluster

ceph-deploy-admin:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls: ceph.deploy.admin
    - require:
        - salt: ceph-deploy-mon

ceph-deploy-osd:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls: ceph.deploy.osd
    - require:
        - salt: ceph-deploy-mon

ceph-deploy-mgr:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls: ceph.deploy.mgr
    - require:
        - salt: ceph-deploy-mon
        - salt: install-ceph-mgr-modules

ceph-deploy-rgw:
  salt.state:
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - sls: ceph.deploy.rgw
    - require:
        - salt: ceph-deploy-osd

ceph-configuration:
  salt.state:
    - tgt: 'ceph:role:*'
    - tgt_type: grain
    - sls: ceph.config
    - require:
        - salt: ceph-deploy-rgw
        - salt: ceph-deploy-mgr

ceph-configure-rgw:
  salt.state:
    - tgt: 'ceph:role:rgw'
    - tgt_type: grain
    - sls: ceph.rgw
    - require:
        - salt: ceph-deploy-rgw
        - salt: ceph-configuration

ceph-cluster-health:
  salt.function:
    - name: cmd.run
    - tgt: 'ceph:role:deploy'
    - tgt_type: grain
    - arg:
        - sudo ceph -s
    - kwarg:
        cwd: /home/ceph-admin/ceph
        runas: ceph-admin
