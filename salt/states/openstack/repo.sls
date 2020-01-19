{% from 'openstack/map.jinja' import release with context %}

openstack-pkgrepo-{{ release }}:
  pkg.installed:
    - name: ubuntu-cloud-keyring
  pkgrepo.managed:
    - humanname: Openstack {{ release }}
    - name: deb http://ubuntu-cloud.archive.canonical.com/ubuntu bionic-updates/{{ release }} main
    - file: /etc/apt/sources.list.d/cloudarchive-{{ release }}.list
