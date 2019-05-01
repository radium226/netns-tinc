prepare_netns()
{
  declare netns_name="${1}"
  declare dns_ip="${2}"

  info "Creating ${netns_name} netns"
  ip netns add "${netns_name}"
  in_netns "${netns_name}" ip address add "127.0.0.1/8" dev "lo"
  in_netns "${netns_name}" ip link set "lo" up

  info "Adding DNS"
  in_netns "${netns_name}" sh -c "echo nameserver ${dns_ip} >'/etc/resolv.conf'"
}

in_netns()
{
  declare netns_name="${1}" ; shift
  ip netns exec "${netns_name}" "${@}"
}

prepare_veth()
{
  #set -x
  declare iface="${1}"
  declare netns_name="${2}"
  declare subnet_number="${3}"
  declare gateway_address="$( iface_ip "${iface}" )"

  info "Creating veth for ${iface} in ${netns_name}"
  ip link add dev "$( veth_iface "${iface}" )" type veth peer name "$( veth_netns_iface "${iface}" )"
  ip link set "$( veth_netns_iface "${iface}" )" netns "${netns_name}"
  ip link set "$( veth_iface "${iface}" )" up
  in_netns "${netns_name}" ip link set "$( veth_netns_iface "${iface}" )" up

  info "Setting IP addresses (10.10.${subnet_number}.*)"
  ip address add "10.10.${subnet_number}.10/31" dev "$( veth_iface "${iface}" )"
  in_netns "${netns_name}" ip address add "10.10.${subnet_number}.11/31" dev "$( veth_netns_iface "${iface}" )"
}

veth_iface()
{
  echo "${1}-host"
}

veth_netns_iface()
{
  echo "${1}-netns"
}
