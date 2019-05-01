#!/bin/bash

set -euo pipefail

for source_file_name in $( ls -1 "./functions.d" | sort ); do
  source "./functions.d/${source_file_name}"
done

export SCRIPT_FILE_PATH="${0}"


export VPN_IFACE="tun0"
export EXTERNAL_IFACE="wlp3s0"
export KIMSUFI_EXTERNAL_IP="91.121.210.84"

export TABLE="vpn"
export MARK="0xa"

tear_down()
{
  ip route flush table "${TABLE}" || true
  clear_ip_rules || true
  clear_iptables || true
  ip netns del "${NETNS}" || true
  ip link del "wlp3s0-host" || true
}

main()
{
  declare arguments="$( getopt -o "m:a:" -l "mode:,action:" -- "$@" )"
  eval set -- "${arguments}"

  declare mode=
  declare action="run"
  while true; do
    case "${1}" in
        -m|--mode)
              mode="${2}"
              shift 2
            ;;
        -a|--action)
              action="${2}"
              shift 2
            ;;
        --)
              shift
              break
            ;;
        *)
              die "Wrong arguments! "
            ;;
    esac
  done

  if [[ -z "${mode}" ]]; then
    die "Mode is not defined! "
  fi

  info "Importing ${mode} mode"
  source "./modes.d/${mode}.sh"

  case "${action}" in
    "run")
        info "Trapping EXIT signal"
        trap "${SCRIPT_FILE_PATH} -m '${mode}' -a 'tear-down'" EXIT

        info "Setting up"
        ${SCRIPT_FILE_PATH} -m "${mode}" -a "set-up"

        info "Executing"
        execute "${@}"
      ;;

    "set-up")
        declare vpn_gateway_ip="$( avahi-resolve -4 -n "kimsufi-01.local" | cut -d"	" -f2 )"
        debug "vpn_gateway_ip=${vpn_gateway_ip}"

        declare vpn_ip="$( iface_ip "${VPN_IFACE}" )"
        debug "vpn_ip=${vpn_ip}"

        info "Allow IP forward"
        echo 1 >"/proc/sys/net/ipv4/ip_forward"

        info "Creating routes in ${TABLE} table"
        ip route add default via "${vpn_gateway_ip}" dev "${VPN_IFACE}" src "${vpn_ip}" table "${TABLE}"

        set_up

        info "Linking ${MARK} mark with ${TABLE} table"
        ip rule add fwmark "${MARK}" priority "100" table "${TABLE}"

        info "Replacing source IP"
        iptables \
          --table "nat" \
          --append "POSTROUTING" \
          --out-interface "${VPN_IFACE}" \
          --match "mark" --mark "${MARK}" \
          --jump "SNAT" \
          --to-source "${vpn_ip}"
      ;;

    "execute")
        execute "${@}"
      ;;

    "tear-down")
        tear_down
      ;;

    *)
        die "Unknown ${action} action! "
      ;;
  esac
}

main "${@}"
exit ${CODE_SUCCESS}
