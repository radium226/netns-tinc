#!/bin/bash

set -euo pipefail

export EXTERNAL_IFACE="wlp3s0"
export VPN_IFACE="tun0"
export NETNS_NAME="toto"

export KIMSUFI_EXTERNAL_IP="91.121.210.84"
export KIMSUFI_INTERNAL_IP="169.254.11.248"
export DNS_IP="8.8.8.8"
export GATEWAY_IP="192.168.0.14"

export COLOR_BLUE="\e[34m"
export COLOR_RED="\e[31m"
export COLOR_GREEN="\e[32m"
export COLOR_DEFAULT="\e[39m"
export COLOR_GREY="\e[90m"

export SUCCESS=0
export FAILURE=1

export STATUS_OK="✓"
export STATUS_KO="✗"

check()
{
  declare label="${1}"; shift
  echo     " --> ${label}: "

  declare in_netns=
  for in_netns in true false; do
    echo -en "      - ["
    set +e
    declare output
    output="$( $( if ${in_netns}; then echo "in_netns"; fi ) "${@}" 2>&1 )"
    declare exit_code="${?}"
    set -e

    if [[ ${exit_code} -eq 0 ]]; then
      echo -en "${COLOR_GREEN}${STATUS_OK}${COLOR_DEFAULT}"
    else
      echo -en "${COLOR_RED}${STATUS_KO}${COLOR_DEFAULT}"
    fi
    echo "] $( ${in_netns} && echo "In netns" || echo "Outside" )"

    if [[ ${exit_code} -ne 0 || ${PRINT_ANYWAY:-0} -eq 1 ]]; then
      echo -e "${COLOR_GREY}${output}${COLOR_DEFAULT}"
    fi
  done
}

export LOCAL_AVAHI_AUTO_IP="$( ip addr show | grep "${VPN_IFACE}:" | grep -o "inet [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" | grep -o "[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*" )"

tear_down()
{
  info "Deleting ${NETNS_NAME} netns"
  ip netns del "${NETNS_NAME}" || true
  clear_ip_rules || true
  clear_iptables || true
}

gateway_ip()
{
  ip route show dev "${1}" | grep default | cut -d' ' -f3
}

ip_address()
{
  declare iface="${1}"
  ip -4 addr show dev "${iface}" | grep "inet" | cut -d" " -f6 | cut -d"/" -f1
}

prepare_veth()
{
  #set -x
  declare iface="${1}"
  declare subnet_number="${2}"
  declare gateway_address="$( ip_address "${iface}" )"

  info "Creating veth for ${iface} in ${NETNS_NAME}"
  ip link add dev "$( veth_iface "${iface}" )" type veth peer name "$( veth_netns_iface "${iface}" )"
  ip link set "$( veth_netns_iface "${iface}" )" netns "${NETNS_NAME}"
  ip link set "$( veth_iface "${iface}" )" up
  in_netns ip link set "$( veth_netns_iface "${iface}" )" up

  info "Setting IP addresses (10.10.${subnet_number}.*)"
  ip address add "10.10.${subnet_number}.10/31" dev "$( veth_iface "${iface}" )"
  in_netns ip address add "10.10.${subnet_number}.11/31" dev "$( veth_netns_iface "${iface}" )"

  #info "Routing between ${iface} and $( veth_iface "${iface}" )"
  #<working>
  #iptables --append "FORWARD" --in-interface "${iface}" --out-interface "$( veth_iface "${iface}" )" --jump "ACCEPT"
  #iptables --append "FORWARD" --in-interface "$( veth_iface "${iface}" )" --out-interface "${iface}" --jump "ACCEPT"
  #</working>
  #set +x
}

set_up()
{
  declare mode="${1:-"--via-host"}"

  prepare_netns
  prepare_veth "${EXTERNAL_IFACE}" 1
  #prepare_veth "${VPN_IFACE}" 2

  info "Setting trafic"

  in_netns ip route add default via "10.10.1.10"

  iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --destination="8.8.8.8" --out-interface "${EXTERNAL_IFACE}" --jump "SNAT"  --to-source "$( ip_address "${EXTERNAL_IFACE}" )"
  iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --destination="${KIMSUFI_EXTERNAL_IP}" --out-interface "${EXTERNAL_IFACE}" --jump "SNAT" --to-source "$( ip_address "${EXTERNAL_IFACE}" )"
  iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --destination="169.254.0.0/16" --out-interface "${VPN_IFACE}" --jump "SNAT" --to-source "$( ip_address "${VPN_IFACE}" )"
  iptables --table "nat" --append "POSTROUTING" --source "10.10.1.11/31" --out-interface "${EXTERNAL_IFACE}" --jump "SNAT" --to-source "$( ip_address "${EXTERNAL_IFACE}" )"
}

log_in()
{
  in_netns bash -i
}

prepare_netns()
{
  info "Allow IP forward"
  echo 1 >"/proc/sys/net/ipv4/ip_forward"

  info "Creating ${NETNS_NAME} netns"
  ip netns add "${NETNS_NAME}"
  in_netns ip address add "127.0.0.1/8" dev "lo"
  in_netns ip link set "lo" up

  info "Adding DNS"
  in_netns sh -c "echo nameserver ${DNS_IP} >'/etc/resolv.conf'"
}

clear_iptables()
{
  info "Clearing IP tables"
  iptables -P "INPUT" "ACCEPT"
  iptables -P "FORWARD" "ACCEPT"
  iptables -P "OUTPUT" "ACCEPT"
  iptables -t "nat" -F
  iptables -t "mangle" -F
  iptables -F
  iptables -X
}

clear_ip_rules()
{
  info "Clearing IP rules"
  ip rule list | sed 's/\t/ /g' | grep -vE "(default|main|local)" | cut -d":" -f1 | xargs -I {} ip rule del pref "{}"
}

check_connectivity()
{
  info "Checking things"
  PRINT_ANYWAY=1 check "External IP"                curl -s      "http://ipinfo.io/ip"
                 check "Ping Google"                ping -4 -w2  "www.google.fr"
                 check "Ping Kimsufi (with .local)" ping -w5     "kimsufi-01.local"
                 check "Ping Kimsufi (with IP)"     ping -w5     "169.254.11.248"
                 check "Ping DNS"                   ping -4 -w2  "8.8.8.8"
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

    "log-in")
        log_in
      ;;

    "ip")
        shift 1
        check_connectivity "${@}"
      ;;
    "test")
        tear_down
        sleep 0.5
        set_up

        check_connectivity
      ;;

    *)
        break
      ;;
  esac
}

error()
{
  echo " [ERROR] ${@}" >&2
}

info()
{
  echo -e "${COLOR_BLUE}${@}${COLOR_DEFAULT}" >&2
}

die()
{
  error "${@}"
  exit ${FAILURE}
}


bridge_iface()
{
  echo "br-${1}"
}

veth_iface()
{
  echo "${1}-host"
}

veth_netns_iface()
{
  echo "${1}-netns"
}

in_netns()
{
  ip netns exec "${NETNS_NAME}" "${@}"
}

main "${@}"
exit ${SUCCESS}
