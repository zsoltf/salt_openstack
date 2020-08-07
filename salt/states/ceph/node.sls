{% set deploy_node = salt['mine.get']('ceph:role:deploy', 'test.ping', 'grain') | first %}

ntpsec:
  pkg.installed: []

openssh-server:
  pkg.installed: []

ceph-admin-user:
  user.present:
    - name: ceph-admin
    - fullname: Cephalopod Adminicus
    - shell: /bin/bash
    - home: /home/ceph-admin
    - groups:
      - sudo

ceph-admin-sudo:
  file.managed:
    - name: /etc/sudoers.d/ceph-admin
    - contents: ceph-admin ALL = (root) NOPASSWD:ALL
    - mode: 440

ceph-admin-ssh-auth:
  ssh_auth.present:
    - name: ceph admin key
    - user: ceph-admin
    - enc: ssh-rsa
    - source: salt://minionfs/{{ deploy_node }}/home/ceph-admin/.ssh/id_rsa.pub
    - require:
      - user: ceph-admin-user

ceph-file-limits:
  file.managed:
    - name: /etc/security/limits.d/file.conf
    - text: |
        *	soft	nofile	1048576
        *	hard	nofile	1048576
        root	soft	nofile	1048576
        root	hard	nofile	1048576

ceph-file-limits-pam:
  file.append:
    - name: /etc/pam.d/common-session
    - text: |
        session required pam_limits.so

ceph-file-limits-pam2:
  file.append:
    - name: /etc/pam.d/common-session-noninteractive
    - text: |
        session required pam_limits.so
