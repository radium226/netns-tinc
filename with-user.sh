#!/bin/bash

set -euo pipefail

for source_file_name in $( ls -1 "./functions.d" | sort ); do
  source "./functions.d/${source_file_name}"
done


export USER="vpn"

export VPN_IFACE="tun0"
export EXTERNAL_IFACE="wlp3s0"

export KIMSUFI_EXTERNAL_IP="91.121.210.84"
export KIMSUFI_INTERNAL_IP="$( avahi-resolve -4 -n "kimsufi-01.local" | cut -d"	" -f2 )"

export DNS_IP="8.8.8.8"

export TABLE="vpn" # /etc/iproute2/rt_table
export MARK="0xa"

check_connectivity()
{
  PRINT_ANYWAY=1 check "External IP"                with_user curl -s      "http://ipinfo.io/ip"
                 check "Ping Google"                with_user ping -4 -w2  "www.google.fr"
                 check "Ping Kimsufi (with .local)" with_user ping -w5     "kimsufi-01.local"
                 check "Ping Kimsufi (with IP)"     with_user ping -w5     "169.254.11.248"
                 check "Ping DNS"                   with_user ping -4 -w2  "8.8.8.8"
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

  info "Setting up ${TABLE} table"
  ip route add "169.254.0.0/16" dev "${VPN_IFACE}" src "${vpn_ip}" table "${TABLE}"
  ip route add "192.168.0.0/24" via "${external_gateway_ip}" dev "${EXTERNAL_IFACE}" src "${external_ip}" table "${TABLE}"
  ip route add default via "${vpn_gateway_ip}" dev "${VPN_IFACE}" src "${vpn_ip}" table "${TABLE}"

  info "Marking packet send by ${USER} with ${MARK} mark"
  iptables --table "mangle" --append "OUTPUT" --match "owner" --uid-owner "${USER}" --jump "MARK" --set-mark "${MARK}"

  info "Adding routing policy on ${MARK} mark to ${TABLE} table"
  ip rule add fwmark "${MARK}" priority "100" table "${TABLE}"

  info "Changing source address to ${vpn_ip}"
  iptables --table "nat" --append "POSTROUTING" --out-interface "${VPN_IFACE}" --match "mark" --mark "${MARK}" --jump "SNAT" --to-source "${vpn_ip}"
}

tear_down()
{
  ip route flush table "${TABLE}"
  clear_ip_rules || true
  clear_iptables || true
}

with_user()
{
  sudo -E -u "${USER}" "${@}"
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
