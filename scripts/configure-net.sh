#!/usr/bin/env bash
# Setzt Adressen, Routen, Port-Isolation, Proxy-ARP, Spiegelung und laedt die
# Firewall-Regeln. Nach containerlab deploy auszufuehren.
#
# Netzkonfiguration erfolgt vom VM-Host per nsenter in den Netzwerk-Namespace
# des Containers. Das funktioniert unabhaengig davon, ob das Container-Image
# ein "ip"-Werkzeug mitbringt oder die noetigen Rechte hat.
#
# Aufruf: sudo ./scripts/configure-net.sh
set -uo pipefail
cd "$(dirname "$0")/.."
P=clab-solodmz

pid()   { docker inspect -f '{{.State.Pid}}' "$P-$1" 2>/dev/null; }
nse()   { local p; p=$(pid "$1"); [ -n "$p" ] && [ "$p" != 0 ] && nsenter -t "$p" -n "${@:2}"; }
addr()  { nse "$1" ip addr add "$2" dev "$3"; nse "$1" ip link set "$3" up; }
route() { nse "$1" ip route add "$2" via "$3"; }
droute(){ nse "$1" ip route add default via "$2"; }
sysc()  { nse "$1" sysctl -qw "$2"; }
ex()    { docker exec "$P-$1" "${@:2}"; }   # nur fuer "nft -f" in den Firewalls

echo "== Warte, bis alle Container laufen =="
for c in $(docker ps -a --filter "name=$P-" --format '{{.Names}}'); do
  for _ in $(seq 1 30); do
    [ "$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null)" = running ] && break
    sleep 1
  done
done

echo "== Adressen =="
# Internet 203.0.113.0/24
addr isp-router   203.0.113.1/24   eth1
addr ang-internet 203.0.113.10/24  eth1
addr inet-server  203.0.113.30/24  eth1
addr ro-gw        203.0.113.40/24  eth1
# Zweigstelle 10.50.0.0/24
addr ro-gw        10.50.0.1/24     eth2
addr ro-client1   10.50.0.10/24    eth1
# Uplink 198.51.100.0/30
addr isp-router   198.51.100.1/30  eth2
addr edge-fw      198.51.100.2/30  eth1
# DMZ /28 je Segment
addr edge-fw      10.0.10.1/28     eth2;  addr rproxy   10.0.10.2/28   eth1
addr edge-fw      10.0.10.17/28    eth3;  addr web      10.0.10.18/28  eth1
addr edge-fw      10.0.10.33/28    eth5;  addr vpn-gw   10.0.10.34/28  eth1
addr edge-fw      10.0.10.49/28    eth6;  addr honeypot 10.0.10.50/28  eth1
# Transit / Router-Link / Backend-Link
addr edge-fw      10.0.255.1/30    eth4;  addr inner-fw 10.0.255.2/30  eth1
addr inner-fw     10.0.254.1/30    eth2;  addr int-router 10.0.254.2/30 eth1
addr inner-fw     10.0.253.1/30    eth3;  addr backend-fw 10.0.253.2/30 eth1
# Client 10.0.20.0/24
addr int-router   10.0.20.1/24     eth2
addr client1      10.0.20.10/24    eth1
addr client2      10.0.20.11/24    eth1
# Backend 10.0.30.0/24
addr backend-fw   10.0.30.1/24     eth2
addr siem-loki    10.0.30.11/24    eth1
addr siem-grafana 10.0.30.10/24    eth1
addr siem-alloy   10.0.30.12/24    eth1

echo "== Routing aktivieren (Firewalls + Router) =="
for n in edge-fw inner-fw int-router backend-fw ro-gw isp-router; do
  sysc "$n" net.ipv4.ip_forward=1
done

echo "== Statische Routen =="
droute edge-fw 198.51.100.1
route  edge-fw 10.0.20.0/24   10.0.255.2
route  edge-fw 10.0.30.0/24   10.0.255.2
route  edge-fw 10.0.253.0/30  10.0.255.2
route  edge-fw 10.0.254.0/30  10.0.255.2
route  edge-fw 10.50.0.0/24   10.0.10.34
droute inner-fw 10.0.255.1
route  inner-fw 10.0.20.0/24  10.0.254.2
route  inner-fw 10.0.30.0/24  10.0.253.2
droute int-router 10.0.254.1
droute backend-fw 10.0.253.1
droute client1 10.0.20.1
droute client2 10.0.20.1
droute siem-loki 10.0.30.1
droute siem-grafana 10.0.30.1
droute siem-alloy 10.0.30.1
droute rproxy   10.0.10.1
droute web      10.0.10.17
droute vpn-gw   10.0.10.33
droute honeypot 10.0.10.49
droute inet-server  203.0.113.1
droute ang-internet 203.0.113.1
droute ro-client1 10.50.0.1

echo "== Client-Port-Isolation (SF-15) =="
bridge link set dev cli-c1 isolated on
bridge link set dev cli-c2 isolated on
sysc int-router net.ipv4.conf.eth2.proxy_arp_pvlan=1
sysc int-router net.ipv4.conf.eth2.send_redirects=0

echo "== Spiegelung zum IDS (SF-09): 8 Punkte, jedes Paket genau einmal =="
./scripts/mirror.sh up

echo "== Firewall-Regeln laden =="
for fw in edge-fw inner-fw backend-fw int-router ro-gw; do
  if [ -f "configs/$fw/nftables.conf" ]; then
    docker cp "configs/$fw/nftables.conf" "$P-$fw:/etc/nftables.conf" >/dev/null
    if ex "$fw" nft -f /etc/nftables.conf; then
      echo "  $fw: Regeln geladen"
    else
      echo "  $fw: FEHLER beim Laden der Regeln (siehe oben)"
    fi
  fi
done

echo "Fertig. Pruefen mit: sudo ./tests/00_topologie.sh und 01_segmentation.sh"
