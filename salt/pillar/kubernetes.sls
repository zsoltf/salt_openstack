{% load_yaml as map %}

base:
  apiserver: 10.9.9.9
  token: qsif7o.1vagz2tz9zuy9d73
  certificate_key: cec4301ea5447f0ba6a06ef8715a553ae9b546e13f458b86a586f29e4562720c
  apiserver_fqdn: kube

home:
  apiserver: 192.168.100.99

test:
  apiserver: 10.193.227.254

boneyard:
  apiserver: 10.250.18.9
  apiserver_fqdn: kubernetes.openstack.bayphoto.com

sv:
  apiserver: 10.5.48.104
  #apiserver: 10.5.49.9
  apiserver_fqdn: kubernetes.openstack.bayphoto.com

{% endload %}
{% set kube = salt['grains.filter_by'](map, grain='datacenter', base='base') %}

kubernetes:
  {{ kube|yaml }}

# network mines
mine_functions:
  ip:
    mine_function: network.ip_addrs
    cidr: 10.0.0.0/8
