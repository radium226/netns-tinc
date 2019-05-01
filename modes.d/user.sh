#!/bin/bash

export USER="vpn"

set_up()
{
  info "Marking ${MARK} mark for ${USER} user"
  iptables --table "mangle" --append "OUTPUT" --match "owner" --uid-owner "${USER}" --jump "MARK" --set-mark "${MARK}"
}

execute()
{
  sudo -u "${USER}" "${@}"
}

tear_down()
{
  ip route flush table "${TABLE}" || true
  clear_ip_rules || true
  clear_iptables || true
}
