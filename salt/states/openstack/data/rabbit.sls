{% from 'openstack/map.jinja' import passwords with context %}

# mq
openstack-message-queue:

  pkg.installed:
    - name: rabbitmq-server

  service.running:
    - name: rabbitmq-server
    - enable: True
    - watch:
        - pkg: openstack-message-queue

  cmd.run:
    - name: |
        rabbitmqctl add_user openstack $rabbit_pass
        rabbitmqctl set_permissions openstack ".*" ".*" ".*"
    - env:
        rabbit_pass: {{ passwords.rabbit_pass }}
    - onchanges:
        - service: openstack-message-queue
