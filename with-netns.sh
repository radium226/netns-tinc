#!/bin/bash

set -euo pipefail

for source_file_name in $( ls -1 "./sources.d" | sort ); do
  source "./sources.d/${source_file_name}"
done


export VPN_IFACE="tun0"
export EXTERNAL_IFACE="wlp3s0"

export KIMSUFI_EXTERNAL_IP="91.121.210.84"
export KIMSUFI_INTERNAL_IP="169.254.11.248"

export DNS_IP="8.8.8.8"

export TABLE="vpn" # /etc/iproute2/rt_table
export MARK="0xa"

export NETNS_NAME="vpn"
export SUBNET_NUMBER=1
export TABLE_NAME="vpn"

check_connectivity()
{
  PRINT_ANYWAY=1 check "External IP"                with_netns curl -s      "http://ipinfo.io/ip"
                 check "Ping Google"                with_netns ping -4 -w2  "www.google.fr"
                 check "Ping Kimsufi (with .local)" with_netns ping -w5     "kimsufi-01.local"
                 check "Ping Kimsufi (with IP)"     with_netns ping -w5     "169.254.11.248"
                 check "Ping DNS"                   with_netns ping -4 -w2  "8.8.8.8"
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
  prepare_veth "${EXTERNAL_IFACE}" "${NETNS_NAME}" ${SUBNET_NUMBER}

  info "Setting up routes"
  in_netns "${NETNS_NAME}" ip route add default via "10.10.${SUBNET_NUMBER}.10"

  ip route add default via "${vpn_gateway_ip}" dev "${VPN_IFACE}" src "${vpn_ip}" table "${TABLE_NAME}"
  ip rule add from "10.10.1.11/31" table "${TABLE_NAME}"
  iptables --table "nat" --append "POSTROUTING" --out-interface "${VPN_IFACE}" --jump "SNAT" --to-source "${vpn_ip}"

  #ip route add nat 205.254.211.17 via 192.168.100.17
  #ip rule add nat 205.254.211.17 from 192.168.100.17
  #ip route flush cache

  #iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --out-interface "${VPN_IFACE}" --jump "MASQUERADE"
  #iptables --append "FORWARD" --out-interface "${VPN_IFACE}" --in-interface "$( veth_iface "${VPN_IFACE}" )" --jump "ACCEPT"
  #iptables --append "FORWARD" --in-interface "${VPN_IFACE}" --out-interface "$( veth_iface "${VPN_IFACE}" )" --jump "ACCEPT"

  #iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --out-interface "${EXTERNAL_IFACE}" --jump "SNAT" --to-source "${external_ip}"
  #iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --out-interface "${VPN_IFACE}" --destination "169.254.0.0/16" --jump "SNAT" --to-source "${vpn_ip}"

}

tear_down()
{
  ip route flush table "${TABLE_NAME}"
  clear_ip_rules || true
  clear_iptables || true
  ip netns del "${NETNS_NAME}" || true
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
exit ${CODE_SUCCESS}
