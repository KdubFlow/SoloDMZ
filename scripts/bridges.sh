#!/usr/bin/env bash
# Legt die Linux-Bridges auf dem VM-Host an bzw. entfernt sie.
# Bridges gibt es fuer Segmente mit mehr als zwei Teilnehmern UND fuer Uplink/Transit,
# damit das IDS dort spiegeln kann. Router-Link und Backend-Link sind direkte Links.
#
# Aufruf: sudo ./scripts/bridges.sh up | down
set -euo pipefail

BRIDGES=(br-internet br-uplink br-remote br-fdmz br-b1dmz br-b2dmz br-hdmz br-transit br-client br-backend)

case "${1:-up}" in
  up)
    for br in "${BRIDGES[@]}"; do
      ip link show "$br" &>/dev/null || ip link add "$br" type bridge
      ip link set "$br" type bridge stp_state 0          # keine Schleifen im Labor
      ip link set "$br" type bridge vlan_filtering 0
      if [ -e "/proc/sys/net/ipv6/conf/$br/disable_ipv6" ]; then
        sysctl -qw "net.ipv6.conf.$br.disable_ipv6=1"    # Bridge bekommt keine IP/kein IPv6
      fi
      ip link set "$br" up
    done
    # Verkehr ueber die Bridges NICHT durch Dockers iptables-FORWARD laufen lassen.
    if [ -e /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
      sysctl -qw net.bridge.bridge-nf-call-iptables=0
      sysctl -qw net.bridge.bridge-nf-call-ip6tables=0
    fi
    echo "Bridges aktiv: ${BRIDGES[*]}"
    ;;
  down)
    for br in "${BRIDGES[@]}"; do ip link del "$br" 2>/dev/null || true; done
    echo "Bridges entfernt."
    ;;
  *)
    echo "Aufruf: $0 up|down" >&2; exit 1 ;;
esac
