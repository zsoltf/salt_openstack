include:
  - .docker_repo

openstack-zun-docker-packages:
  pkg.installed:
    - pkgs:
        - docker-ce
        - docker-ce-cli
        - containerd.io

openstack-zun-docker-config:
  file.managed:
    - name: /etc/docker/daemon.json
    - makedirs: True
    - contents: |
        {
          "exec-opts": ["native.cgroupdriver=systemd"],
          "log-driver": "json-file",
          "log-opts": {
            "max-size": "100m"
          },
          "storage-driver": "overlay2"
        }

openstack-zun-docker-service:
  service.running:
    - name: docker
    - require:
      - pkg: openstack-zun-docker-packages
    - watch:
      - file: openstack-zun-docker-config
