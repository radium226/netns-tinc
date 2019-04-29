#!/bin/bash

set -e

LOCAL_AVAHI_AUTO_IP="$( ip addr show | grep tun0 | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" )"

ip route add 91.121.210.84 via 192.168.0.254 dev wlp3s0 # EXTERNAL KIMSUFI IP
ip route add 8.8.8.8 via 192.168.0.254 dev wlp3s0 #DNS
ip route del default via 192.168.0.254 dev wlp3s0 # FREEBOX IP
ip route add default via $( avahi-resolve -4 -n kimsufi-01.local | cut -d"	" -f2 ) src ${LOCAL_AVAHI_AUTO_IP} #AVAHI AUTO IP

#VPN_GATEWAY="$( avahi-resolve -4 -n kimsufi-01.local | cut -d'	' -f2 )"
#INTERFACE=tun0
#ip route add $REMOTEADDRESS $ORIGINAL_GATEWAY
#ip route add $VPN_GATEWAY dev $INTERFACE
#ip route add 0.0.0.0/1 via $VPN_GATEWAY dev $INTERFACE
#ip route add 128.0.0.0/1 via $VPN_GATEWAY dev $INTERFACE
