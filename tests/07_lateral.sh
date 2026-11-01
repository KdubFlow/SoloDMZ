#!/usr/bin/env bash
# T07/T11/T12 - Laterale Bewegung und Egress aus der DMZ scheitern,
#               Webserver nur vom Proxy erreichbar.
# Aufruf: sudo ./tests/07_lateral.sh
set -uo pipefail
P=clab-solodmz
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }
yes(){ local d="$1"; shift; if docker exec "$P-$1" "${@:2}" &>/dev/null; then ok "$d"; else nok "$d (sollte gehen)"; fi; }
no(){ local d="$1"; shift; if docker exec "$P-$1" "${@:2}" &>/dev/null; then nok "$d (sollte blockiert sein)"; else ok "$d"; fi; }
PING="ping -c1 -W2"

echo "== T11 Webserver-Erreichbarkeit =="
yes "rproxy -> web:80 (F05)"        rproxy curl -s --max-time 4 http://10.0.10.18/
no  "vpn-gw -> web direkt"          vpn-gw $PING 10.0.10.18
no  "client1 -> web direkt"         client1 $PING 10.0.10.18

echo "== T07 Laterale Bewegung aus der DMZ =="
no  "rproxy -> vpn-gw"              rproxy $PING 10.0.10.34
no  "rproxy -> honeypot"           rproxy $PING 10.0.10.50
no  "rproxy -> inner-fw/Transit"   rproxy $PING 10.0.255.2

echo "== T12 Egress aus der DMZ =="
yes "rproxy -> inet-server (F13)"  rproxy curl -s --max-time 4 http://203.0.113.30/
no  "rproxy -> Angreifer im Netz"  rproxy curl -s --max-time 4 http://203.0.113.10/
no  "honeypot -> irgendwohin"      honeypot $PING 203.0.113.30

echo; echo "Ergebnis: $pass PASS, $fail FAIL"
[ "$fail" -eq 0 ]
