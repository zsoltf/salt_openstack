{% from 'openstack/map.jinja' import controller, memcache with context %}

openstack-dashboard:
  pkg.installed:
    - pkgs:
      - openstack-dashboard
      - fonts-roboto

# minimal config

openstack-dashboard-config-1:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - pattern: ^OPENSTACK_HOST = .*
    - repl: OPENSTACK_HOST = '{{ controller }}'

openstack-dashboard-config-2:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - append_if_not_found: True
    - pattern: ^SESSION_ENGINE = .*
    - repl: SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

openstack-dashboard-config-3:
  file.replace:
    - name: /etc/openstack-dashboard/local_settings.py
    - pattern: '127.0.0.1:11211'
    - repl: '{{ memcache }}:11211'

#openstack-dashboard-config-4:
#  file.replace:
#    - name: /etc/openstack-dashboard/local_settings.py
#    - append_if_not_found: True
#    - pattern: ^DEFAULT_THEME = .*
#    - repl: DEFAULT_THEME = 'default'

openstack-dashboard-config-5:
  file.replace:
    - name: /usr/share/openstack-dashboard/openstack_dashboard/themes/material/static/horizon/_styles.scss
    - pattern: ^@import "icons";
    - repl: '#@import "icons";'

openstack-dashboard-config-6:
  cmd.run:
    - name: |
        cp -r /usr/share/openstack-dashboard/openstack_dashboard/themes/material \
          /usr/share/openstack-dashboard/openstack_dashboard/themes/dark
    - creates: /usr/share/openstack-dashboard/openstack_dashboard/themes/dark

openstack-dashboard-config-7:
  cmd.run:
    - name: |
        cp -r /usr/share/openstack-dashboard/openstack_dashboard/themes/material \
          /usr/share/openstack-dashboard/openstack_dashboard/themes/light
    - creates: /usr/share/openstack-dashboard/openstack_dashboard/themes/light

openstack-dashboard-config-8:
  file.managed:
    - name: /usr/share/openstack-dashboard/openstack_dashboard/themes/dark/static/bootstrap/_styles.scss
    - contents: |
        // original
        @import "/horizon/lib/bootstrap_scss/scss/bootstrap/mixins/vendor-prefixes";
        @import "/horizon/lib/roboto_fontface/css/roboto/sass/roboto-fontface.scss";
        // Patch to Paper
        // Inside alerts, the text color of buttons aren't properly ignored
        // https://github.com/thomaspark/bootswatch/issues/552
        .alert a:not(.close).btn-primary {
          color: $btn-primary-color;
        }
        .alert a:not(.close).btn-default {
          color: $btn-default-color;
        }
        .alert a:not(.close).btn-info {
          color: $btn-info-color;
        }
        .alert a:not(.close).btn-warning {
          color: $btn-warning-color;
        }
        .alert a:not(.close).btn-danger {
          color: $btn-danger-color;
        }

        .alert a.close {
          font-size: $font-size-h5;
        }

        // overrides
        @import "/horizon/lib/bootswatch/cyborg/bootswatch";
        body.md-default-theme, body, html.md-default-theme, html {
          background-color: #060606;
          scrollbar-color: #979797 #060606;
          font-family: monospace;
        }

        h1 {
          font-family: monospace;
        }

        .btn-default.active {
          background-color: $brand-primary;
        }

        .table-striped.datatable tbody tr.even td {
          background-color: $gray-dark;
        }

        .form-control, .datepicker input {
          background-color: $gray-dark;
          border: 1px solid #979797;
        }

        .container-fluid {
          background-color: #060606;
        }

        #sidebar .openstack-panel > a.active {
          background-color: $brand-primary;
        }

        #sidebar .openstack-dashboard > a {
          font-size: large;
        }

        #sidebar .openstack-dashboard > a:active {
          color: #3b3b3b;
          background-color: $brand-primary;
        }

        #sidebar .openstack-dashboard > a:focus {
          color: #3b3b3b;
          background-color: $brand-primary;
        }

        #sidebar .nav-header > a:hover {
          background-color: #3b3b3b;
        }

        #sidebar .nav-header > a:focus {
          color: #3b3b3b;
          background-color: $brand-primary;
        }

        #sidebar .nav-header > a:focus {
          background-color: #3b3b3b;
        }

        .themable-checkbox input[type="checkbox"]:checked + label::before {
          color: #ececec;
        }

        .modal-lg {
          width: 1200px;
        }

openstack-dashboard-config-9:
  file.managed:
    - name: /usr/share/openstack-dashboard/openstack_dashboard/themes/dark/static/bootstrap/_variables.scss
    - contents: |
        // original
        $web-font-path: $static_url + "horizon/lib/roboto_fontface/css/roboto/roboto-fontface.css";
        $roboto-font-path: $static_url + "horizon/lib/roboto_fontface/fonts";
        @import "variable_customizations";
        // override
        @import "/horizon/lib/bootswatch/cyborg/variables";


openstack-dashboard-config-10:
  file.append:
    - name: /etc/openstack-dashboard/local_settings.py
    - text: |
        AVAILABLE_THEMES = [
        ('default', 'Default', 'themes/default'),
        ('dark', 'Dark', 'themes/dark'),
        ('light', 'Light', 'themes/light'),
        ]
        DEFAULT_THEME = 'dark'


openstack-dashboard-service:
  service.running:
    - name: apache2
    - watch:
      - file: openstack-dashboard-config-1
      - file: openstack-dashboard-config-2
      - file: openstack-dashboard-config-3
      #- file: openstack-dashboard-config-4
