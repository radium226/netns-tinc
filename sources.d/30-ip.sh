#!/bin/bash

iface_gateway_ip()
{
  declare iface="${1}"
  ip -4 route show dev "${iface}" | grep "default" | cut -d' ' -f3
}

iface_ip()
{
  declare iface="${1}"
  ip -4 addr show dev "${iface}" | grep "inet" | cut -d" " -f6 | cut -d"/" -f1
}
