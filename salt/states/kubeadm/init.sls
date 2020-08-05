include:
  - .docker
  - repos.google-cloud

kubernetes-pillar-configured:
  test.check_pillar:
    - present:
        - kubernetes

kubeadm-packages:
  pkg.installed:
    - pkgs:
        - kubeadm
        - kubectl
        - kubelet
    - hold: True
    - require:
        - google-cloud-repo

kubelet-service:
  service.running:
    - name: kubelet


# for targeting the first node in orchestrate; maybe there is a better way?
# this fails on first run :(

{% set first_master = salt['mine.get']('kube:role:master', 'test.ping', 'grain') | dictsort() | first | first %}
{% set first_etcd = salt['mine.get']('kube:role:etcd', 'test.ping', 'grain') | dictsort() | first | first %}

{% if grains['id'] == first_master %}

first_master_grain:
  grains.present:
    - name: kube:first_master
    - value: 'true'

{% elif grains['id'] == first_etcd %}

first_etcd_grain:
  grains.present:
    - name: kube:first_etcd
    - value: 'true'

{% endif %}
