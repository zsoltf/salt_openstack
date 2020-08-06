{% set passwords = salt['pillar.get']('openstack:passwords') %}
{# set monitor = salt['mine.get']('openstack:role:monitor', 'test.ping', 'grain') | first #}
{% set mon = salt['mine.get']('ceph:role:mon', 'test.ping', 'grain') | join(' ') %}

ceph-cluster-mgr:
  cmd.run:
    - name: ceph-deploy mgr create {{ mon }}
    - cwd: /home/ceph-admin/ceph
    - runas: ceph-admin
    - unless: sudo ceph mgr versions

#ceph-mgr-enable-dashboard:
#  cmd.run:
#    - name: |
#        sudo ceph mgr module enable dashboard
#        sudo ceph config set mgr mgr/dashboard/ssl false
#        sudo ceph mgr module disable dashboard
#        sudo ceph mgr module enable dashboard
#        sudo ceph mgr module enable prometheus
#        sudo ceph dashboard set-grafana-api-url http://{{ monitor }}:3000
#        sudo ceph dashboard ac-user-create admin $admin_pass administrator
#    - env:
#        admin_pass: {{ passwords.admin_pass }}
#    - cwd: /home/ceph-admin/ceph
#    - runas: ceph-admin
#    - unless: sudo ceph mgr module ls | head -20 | grep dashboard
