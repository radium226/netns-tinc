#!/bin/bash

export NETNS="vpn"
export DNS_IP="8.8.8.8"
export SUBNET_NUMBER=1

set_up()
{
  info "Creating ${NETNS} network namespace"
  prepare_netns "${NETNS}" "${DNS_IP}"
  prepare_veth "${EXTERNAL_IFACE}" "${NETNS}" ${SUBNET_NUMBER}
  in_netns "${NETNS}" ip route add default via "10.10.${SUBNET_NUMBER}.10"

  info "Setting up NAT"
  ip rule add from "10.10.${SUBNET_NUMBER}.11/31" table "${TABLE}"

  iptables --table "nat" --append "PREROUTING" --source "10.10.${SUBNET_NUMBER}.11/31" --jump "MARK" --set-mark "${MARK}"
}

execute()
{
  in_netns "${NETNS}" "${@}"
}

tear_down()
{
  ip route flush table "${TABLE}" || true
  clear_ip_rules || true
  clear_iptables || true
  ip netns del "${NETNS}" || true
}
