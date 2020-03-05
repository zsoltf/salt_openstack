openstack-vitrage-aodh-config:
  ini.options_present:
    - name: /etc/aodh/aodh.conf
    - sections:
        DEFAULT:
          notification_topics: notifications,vitrage_notifications
          notification_driver: messagingv2
        notifications:
          versioned_notifications_topics: versioned_notifications,vitrage_notifications
          notification_driver: messagingv2
        oslo_messaging_notifications:
          driver: messagingv2
          topics: notifications,vitrage_notifications

openstack-vitrage-nova-config:
  ini.options_present:
    - name: /etc/nova/nova.conf
    - sections:
        DEFAULT:
          notification_topics: notifications,vitrage_notifications
          notification_driver: messagingv2
        notifications:
          versioned_notifications_topics: versioned_notifications,vitrage_notifications
          notification_driver: messagingv2

openstack-vitrage-neutron-config:
  ini.options_present:
    - name: /etc/neutron/neutron.conf
    - sections:
        DEFAULT:
          notification_topics: notifications,vitrage_notifications
          notification_driver: messagingv2
        notifications:
          versioned_notifications_topics: versioned_notifications,vitrage_notifications
          notification_driver: messagingv2


openstack-vitrage-heat-config:
  ini.options_present:
    - name: /etc/heat/heat.conf
    - sections:
        DEFAULT:
          notification_topics: notifications,vitrage_notifications
          notification_driver: messagingv2
        notifications:
          versioned_notifications_topics: versioned_notifications,vitrage_notifications
          notification_driver: messagingv2

openstack-vitrage-cinder-config:
  ini.options_present:
    - name: /etc/cinder/cinder.conf
    - sections:
        DEFAULT:
          notification_topics: notifications,vitrage_notifications
          notification_driver: messagingv2
        notifications:
          versioned_notifications_topics: versioned_notifications,vitrage_notifications
          notification_driver: messagingv2


