#!/usr/bin/env bash
# T01 - Kommunikationsmatrix: erlaubte Fluesse gehen, verbotene nicht.
# Aufruf: sudo ./tests/01_segmentation.sh
set -uo pipefail
P=clab-solodmz
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }
# erwartet Erfolg
yes(){ local d="$1"; shift; if docker exec "$P-$1" "${@:2}" &>/dev/null; then ok "$d"; else nok "$d (sollte gehen)"; fi; }
# erwartet Misserfolg (geblockt)
no(){ local d="$1"; shift; if docker exec "$P-$1" "${@:2}" &>/dev/null; then nok "$d (sollte blockiert sein)"; else ok "$d"; fi; }

PING="ping -c1 -W2"
echo "== Erlaubt =="
yes "F08 client1 -> inet-server (HTTP)" client1 curl -s --max-time 4 http://203.0.113.30/
yes "F09 client1 -> rproxy (HTTPS/WAF)" client1 curl -sk --max-time 4 https://10.0.10.2/
yes "client1 -> int-router (Gateway)"   client1 $PING 10.0.20.1

echo "== Verboten =="
no "Client -> Webserver direkt"          client1 $PING 10.0.10.18
no "Client -> VPN-GW direkt"             client1 $PING 10.0.10.34
no "Client -> Backend (SIEM)"            client1 $PING 10.0.30.11
no "Client -> Honeypot direkt"           client1 $PING 10.0.10.50
no "Internet-Angreifer -> Webserver"     ang-internet $PING 10.0.10.18
no "Internet-Angreifer -> interner Client" ang-internet $PING 10.0.20.10
no "DMZ rproxy -> interner Client"        rproxy $PING 10.0.20.10
no "DMZ rproxy -> Backend"               rproxy $PING 10.0.30.11

echo; echo "Ergebnis: $pass PASS, $fail FAIL"
[ "$fail" -eq 0 ]
