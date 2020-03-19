#!/bin/bash

set -euo pipefail

#set -x

for source_file_name in $( ls -1 "./functions.d" | sort ); do
  source "./functions.d/${source_file_name}"
done

export NETNS_NAME="vpn"
export SUBNET_NUMBER=1

export DNS_IP="8.8.8.8"

export VPN_IFACE="tun0"
export EXTERNAL_IFACE="wlp3s0"

export TABLE_NAME="2"
export MARK_NUMBER="4"

export KIMSUFI_EXTERNAL_IP="91.121.210.84"
export KIMSUFI_INTERNAL_IP="$( avahi-resolve -4 -n "kimsufi-01.local" | cut -d"	" -f2 )"

check_connectivity()
{
  PRINT_ANYWAY=1 check "External IP"                   with_netns curl -s           "http://ipinfo.io/ip"
  PRINT_ANYWAY=1 check "External IP (without resolve)" with_netns curl -s --resolve "ipinfo.io:80:216.239.38.21" "http://ipinfo.io/ip"
                 check "Ping Google"                   with_netns ping -4 -w2       "www.google.fr"
                 check "Ping ODroid (with .local)"     with_netns ping -w5          "odroid-01.local"
                 #check "Ping Kimsufi (with IP)"        with_netns ping -w5          "${KIMSUFI_INTERNAL_IP}"
                 check "Ping DNS"                      with_netns ping -4 -w2       "8.8.8.8"
                 check "Check Python server"           true       nc   -zv          "10.10.${SUBNET_NUMBER}.11" 8000
}

set_up()
{
  declare external_gateway_ip="$( iface_gateway_ip "${EXTERNAL_IFACE}" )"
  declare external_ip="$( iface_ip "${EXTERNAL_IFACE}" )"
  debug "external_ip=${external_ip}"
  debug "external_gateway_ip=${external_gateway_ip}"

  declare vpn_gateway_ip="${KIMSUFI_INTERNAL_IP}"
  declare vpn_ip="$( iface_ip "${VPN_IFACE}" )"
  debug "vpn_gateway_ip=${vpn_gateway_ip}"
  debug "vpn_ip=${vpn_ip}"

  info "Allow IP forward"
  echo 1 >"/proc/sys/net/ipv4/ip_forward"

  info "Create ${NETNS_NAME} network namespace"
  prepare_netns "${NETNS_NAME}" "${DNS_IP}"
  prepare_veth "${NETNS_NAME}" ${SUBNET_NUMBER}

  info "Setting up routes"
  in_netns "${NETNS_NAME}" ip route add default via "10.10.${SUBNET_NUMBER}.10"

  iptables \
    --table "nat" \
    --append "POSTROUTING" \
    --source "10.10.${SUBNET_NUMBER}.11/31" \
    --out-interface "${EXTERNAL_IFACE}" \
    --jump "SNAT" \
    --to-source "$( iface_ip "${EXTERNAL_IFACE}" )"

  ip route add default via "${vpn_gateway_ip}" dev "${VPN_IFACE}" src "${vpn_ip}" table "${TABLE_NAME}"
  ip route add "10.10.1.10/31" via "10.10.1.10" dev "$( veth_iface "${NETNS_NAME}" )" src "10.10.1.10"  table "${TABLE_NAME}"
  ip route add "192.168.0.0/24" via "${external_gateway_ip}" dev "${EXTERNAL_IFACE}" src "${external_ip}" table "${TABLE_NAME}"
  ip rule add from "10.10.1.11/31" table "${TABLE_NAME}"
  #ip route flush cache
  #ip rule add fwmark "${MARK_NUMBER}" priority "100" table "${TABLE_NAME}"
  ip route flush cache

  iptables \
    --table "nat" \
    --append "PREROUTING" \
    --source "10.10.1.11/31" \
    --jump "MARK" \
    --set-mark "${MARK_NUMBER}"

  iptables \
    --table "nat" \
    --append "POSTROUTING" \
    --out-interface "${VPN_IFACE}" \
    --jump "SNAT" \
    --to-source "${vpn_ip}"

  info "Starting Python server"
  {
    in_netns "${NETNS_NAME}" python -m "http.server"
  } &
  sleep 2.5
  debug "Done! "
  sleep 2.5

  #ip route add default via "${vpn_gateway_ip}" dev "${VPN_IFACE}" src "${vpn_ip}" table "${TABLE_NAME}"
  #ip rule add from "10.10.1.11/31" table "${TABLE_NAME}"
  #ip route flush cache

  #ip rule add fwmark "${MARK_NUMBER}" priority "100" table "${TABLE_NAME}"
  #iptables --table "nat" --append "PREROUTING" --source "10.10.1.11/31" --jump "MARK" --set-mark "${MARK_NUMBER}"

  #iptables --table "nat" --append "POSTROUTING" --out-interface "${VPN_IFACE}" --jump "SNAT" --to-source "${vpn_ip}"
}

tear_down()
{
  pkill -f "http.server" || true
  ip route flush table "${TABLE_NAME}"
  clear_ip_rules || true
  clear_iptables || true
  ip netns del "${NETNS_NAME}" || true

  iptables -t nat -F && iptables -t mangle -F && iptables -F && iptables -X || true

  ip link del "$( veth_iface "${NETNS_NAME}" )" || true
}

with_netns()
{
  in_netns "${NETNS_NAME}" "${@}"
}

main() {
  declare action="${1:-test}"

  case "${action}" in
    "set-up")
        set_up
      ;;

    "tear-down")
        tear_down
      ;;

    "test")
        tear_down
        sleep 0.5
        set_up

        check_connectivity
      ;;

    *)
        check_connectivity
      ;;
  esac
}

main "${@}"
exit ${?}
