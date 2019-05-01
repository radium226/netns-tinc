#!/bin/bash

clear_ip_rules()
{
  info "Clearing IP rules"
  ip rule list | sed 's/\t/ /g' | grep -vE "(default|main|local)" | cut -d":" -f1 | xargs -I {} ip rule del pref "{}"
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
