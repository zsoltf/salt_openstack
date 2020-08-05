switch-1-options:
  netconfig.managed:
    - template_name: salt://network/options.jinja
    - options:
      - hostname boneswitch-1
      - ip name-server vrf default 10.5.48.8
      - ip name-server vrf default 10.5.48.9
      - ip domain-list discdrive.bayphoto.com
      - ip route 0.0.0.0/0 10.250.18.1
      - no aaa root
      - no ip routing
      - username admin role network-admin secret sha512 $6$JX7ZnaFm0jJjNZPI$7HdahwDXaoOyR5rnyYd09BGU2/j9ADQJ5rMW94mbB31CG7b/Das8dyGVKF.BAyJmD8WakCf4xFcUNOxyDl5O10

switch-1-settings:
  netconfig.managed:
    - template_name: salt://network/settings.jinja
    - settings:
        interface Management1: |
          ip address 10.250.18.254/23
        management api http-commands: |
          protocol http
          protocol unix-socket
          no shutdown
        management ssh : |
          idle-timeout 180
        event-handler boot-up-script: |
          trigger on-boot
          action bash sudo /mnt/flash/startup.sh

switch-1-mlag:
  netconfig.managed:
    - template_name: salt://network/mlag.jinja
    - interfaces:
        - Ethernet50/1
        - Ethernet52/1
    - port_channel: 10
    - vlan: 4094
    - ip_address: 10.9.9.1/30
    - peer_address: 10.9.9.2
    - domain_id: boneyard
