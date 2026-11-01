#!/usr/bin/env bash
# Setzt Adressen, Routen, Port-Isolation, Proxy-ARP, Spiegelung und laedt die
# Firewall-Regeln in die Namespaces. Nach containerlab deploy auszufuehren.
#
# Aufruf: sudo ./scripts/configure-net.sh
set -euo pipefail
cd "$(dirname "$0")/.."
P=clab-solodmz   # Containerlab-Praefix (lab name = solodmz)

ex() { docker exec "$P-$1" "${@:2}"; }                 # Befehl im Container
addr() { ex "$1" ip addr add "$2" dev "$3"; ex "$1" ip link set "$3" up; }
route() { ex "$1" ip route add "$2" via "$3"; }

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
# DMZ /28 je Segment (Firewall .1/.17/.33/.49)
addr edge-fw      10.0.10.1/28     eth2;  addr rproxy   10.0.10.2/28   eth1
addr edge-fw      10.0.10.17/28    eth3;  addr web      10.0.10.18/28  eth1
addr edge-fw      10.0.10.33/28    eth5;  addr vpn-gw   10.0.10.34/28  eth1
addr edge-fw      10.0.10.49/28    eth6;  addr honeypot 10.0.10.50/28  eth1
# Transit / Router-Link / Backend-Link (/30)
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
  ex "$n" sysctl -qw net.ipv4.ip_forward=1
done

echo "== Statische Routen =="
# ISP kennt nur die oeffentliche Firmen-IP (keine Route in Firmennetze)
# Edge-FW
route edge-fw 10.0.20.0/24   10.0.255.2
route edge-fw 10.0.30.0/24   10.0.255.2
route edge-fw 10.0.253.0/30  10.0.255.2
route edge-fw 10.0.254.0/30  10.0.255.2
route edge-fw 10.50.0.0/24   10.0.10.34   # Zweigstelle hinter dem VPN-GW
ex edge-fw ip route add default via 198.51.100.1
# Inner-FW
ex inner-fw ip route add default via 10.0.255.1
route inner-fw 10.0.20.0/24  10.0.254.2
route inner-fw 10.0.30.0/24  10.0.253.2
# Router / Backend-FW / Clients / SOC
ex int-router ip route add default via 10.0.254.1
ex backend-fw ip route add default via 10.0.253.1
for n in client1 client2; do ex "$n" ip route add default via 10.0.20.1; done
for n in siem-loki siem-grafana siem-alloy; do ex "$n" ip route add default via 10.0.30.1; done
# DMZ-Dienste: Default ueber ihre Edge-FW-Adresse
ex rproxy   ip route add default via 10.0.10.1
ex web      ip route add default via 10.0.10.17
ex vpn-gw   ip route add default via 10.0.10.33
ex honeypot ip route add default via 10.0.10.49
# inet-server / ang-internet
ex inet-server  ip route add default via 203.0.113.1
ex ang-internet ip route add default via 203.0.113.1
# Zweigstelle: Full Tunnel -> Default ueber wg0 wird in configs/ro-gw gesetzt
ex ro-client1 ip route add default via 10.50.0.1

echo "== Client-Port-Isolation (SF-15) =="
# Clients duerfen L2 nur mit dem Router-Port sprechen; Proxy-ARP am Router vermittelt.
bridge link set dev cli-c1 isolated on
bridge link set dev cli-c2 isolated on
ex int-router sysctl -qw net.ipv4.conf.eth2.proxy_arp_pvlan=1
ex int-router sysctl -qw net.ipv4.conf.eth2.send_redirects=0

echo "== Spiegelung zum IDS (SF-09): 8 Punkte, jedes Paket genau einmal =="
./scripts/mirror.sh up

echo "== Firewall-Regeln laden =="
for fw in edge-fw inner-fw backend-fw int-router ro-gw; do
  if [ -f "configs/$fw/nftables.conf" ]; then
    docker cp "configs/$fw/nftables.conf" "$P-$fw:/etc/nftables.conf"
    ex "$fw" nft -f /etc/nftables.conf
    echo "  $fw: Regeln geladen"
  fi
done

echo "Fertig. Pruefen mit: sudo ./tests/00_topologie.sh und 01_segmentation.sh"
