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
  declare netns_name="${1}"
  declare subnet_number="${2}"


  info "Creating veth for ${netns_name} network namespace"
  ip link add dev "$( veth_iface "${netns_name}" )" type veth peer name "$( veth_netns_iface "${netns_name}" )"
  ip link set "$( veth_netns_iface "${netns_name}" )" netns "${netns_name}"
  ip link set "$( veth_iface "${netns_name}" )" up
  in_netns "${netns_name}" ip link set "$( veth_netns_iface "${netns_name}" )" up

  info "Setting IP addresses (10.10.${subnet_number}.*)"
  ip address add "10.10.${subnet_number}.10/31" dev "$( veth_iface "${netns_name}" )"
  in_netns "${netns_name}" ip address add "10.10.${subnet_number}.11/31" dev "$( veth_netns_iface "${netns_name}" )"
}

veth_iface()
{
  declare netns_name="${1}"
  echo "${netns_name}-out0"
}

veth_netns_iface()
{
  declare netns_name="${1}"
  echo "${netns_name}-in0"
}
