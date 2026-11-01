#!/usr/bin/env bash
# Startet den Site-to-Site-Tunnel vpn-gw (Zentrale) <-> ro-gw (Zweigstelle), SF-07.
# Idempotent: erzeugt Schluessel, falls keine da sind (auch nach Redeploy).
# Aufruf: sudo ./scripts/vpn-up.sh
set -uo pipefail
P=clab-solodmz

modprobe wireguard 2>/dev/null || true

# Schluessel je GW anlegen, falls noch nicht vorhanden
for gw in vpn-gw ro-gw; do
  docker exec "$P-$gw" sh -c '[ -f /etc/wg_priv ] || { wg genkey > /etc/wg_priv; chmod 600 /etc/wg_priv; }'
done
VPNGW_PUB=$(docker exec "$P-vpn-gw" sh -c 'wg pubkey < /etc/wg_priv')
ROGW_PUB=$(docker exec "$P-ro-gw"  sh -c 'wg pubkey < /etc/wg_priv')
echo "vpn-gw  oeffentlicher Schluessel: $VPNGW_PUB"
echo "ro-gw   oeffentlicher Schluessel: $ROGW_PUB"

# --- Zentrale: vpn-gw, Tunnel-IP 10.9.0.1 ---
docker exec "$P-vpn-gw" sh -c "
  ip link del wg0 2>/dev/null
  ip link add wg0 type wireguard
  ip addr add 10.9.0.1/30 dev wg0
  wg set wg0 listen-port 51820 private-key /etc/wg_priv \
     peer $ROGW_PUB allowed-ips 10.9.0.2/32,10.50.0.0/24
  ip link set wg0 up
  ip route replace 10.50.0.0/24 dev wg0
"

# --- Zweigstelle: ro-gw, Tunnel-IP 10.9.0.2, Full Tunnel ---
docker exec "$P-ro-gw" sh -c "
  ip link del wg0 2>/dev/null
  ip link add wg0 type wireguard
  ip addr add 10.9.0.2/30 dev wg0
  wg set wg0 private-key /etc/wg_priv \
     peer $VPNGW_PUB endpoint 198.51.100.2:51820 allowed-ips 0.0.0.0/0 persistent-keepalive 25
  ip link set wg0 up
  ip route add 198.51.100.2/32 via 203.0.113.1 2>/dev/null   # Endpunkt ueber echtes Internet
  ip route replace default dev wg0                           # alles andere durch den Tunnel
"

echo "VPN aktiv. Pruefen mit: sudo docker exec $P-vpn-gw wg show"
