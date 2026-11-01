#!/usr/bin/env bash
# Spiegelung (SF-09): kopiert den Ingress-Verkehr der gespiegelten Bridge-Ports
# per tc auf veth-Paare, deren anderes Ende im ids-Container als ethN liegt.
# Der Client-Router-Port filtert Pakete aus dem Client-Netz aus (keine Doppelung).
#
# Aufruf: sudo ./scripts/mirror.sh up | down
set -euo pipefail
P=clab-solodmz

# Quelle-Bridge-Port -> IDS-Interface
declare -A MIR=(
  [upl-edge]=eth1      # Uplink
  [fdmz-rpx]=eth2      # F-DMZ
  [b1-web]=eth3        # B1-DMZ
  [b2-vpn]=eth4        # B2-DMZ
  [hdmz-hp]=eth5       # H-DMZ
  [tr-edge]=eth6       # Transit
  [cli-rtr]=eth7       # Client
  [be-bfw]=eth8        # Backend
)

ids_pid() { docker inspect -f '{{.State.Pid}}' "$P-ids"; }

case "${1:-up}" in
  up)
    PID=$(ids_pid)
    i=0
    for src in "${!MIR[@]}"; do
      dev="${MIR[$src]}"; host="mir$i"; i=$((i+1))
      # veth-Paar: host-Ende bleibt hier, ids-Ende wandert in den ids-Namespace
      ip link show "$host" &>/dev/null || ip link add "$host" type veth peer name "p-$host"
      ip link set "p-$host" netns "$PID" name "$dev"
      nsenter -t "$PID" -n ip link set "$dev" up
      ip link set "$host" up
      # tc: Ingress des Quell-Ports auf das host-Ende spiegeln
      tc qdisc add dev "$src" handle ffff: ingress 2>/dev/null || true
      if [ "$src" = "cli-rtr" ]; then
        # Client-Router-Port: vom Client stammende Pakete NICHT erneut spiegeln
        tc filter add dev "$src" ingress prio 1 protocol ip flower src_ip 10.0.20.0/24 action pass
      fi
      tc filter add dev "$src" ingress prio 2 matchall action mirred egress mirror dev "$host"
    done
    echo "Spiegelung aktiv: ${!MIR[*]}"
    ;;
  down)
    for src in "${!MIR[@]}"; do tc qdisc del dev "$src" ingress 2>/dev/null || true; done
    for h in mir0 mir1 mir2 mir3 mir4 mir5 mir6 mir7; do ip link del "$h" 2>/dev/null || true; done
    echo "Spiegelung entfernt."
    ;;
  *) echo "Aufruf: $0 up|down" >&2; exit 1 ;;
esac
