openstack-horizon-dashboard:
  cmd.run:
    - name: |
        apt-get -qq install -y python3-pip
        git clone -b stable/train https://opendev.org/openstack/horizon --depth=1
        cd horizon
        pip3 install -r requirements.txt
        pip3 install .
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 ./manage.py collectstatic --noinput
        DJANGO_SETTINGS_MODULE=openstack_dashboard.settings python3 ./manage.py compress --force
