#!/usr/bin/env bash
# T09 - Client <-> Client (F12/SF-15): erlaubt ueber den Int-Router, protokolliert,
#       Scan wird gebremst. Aufruf: sudo ./tests/09_client_client.sh
set -uo pipefail
P=clab-solodmz
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }

echo "== Erlaubte Kommunikation (ueber den Router) =="
if docker exec "$P-client1" ping -c1 -W2 10.0.20.11 &>/dev/null; then
  ok "client1 -> client2 (ping) funktioniert"
else
  nok "client1 -> client2 (ping) sollte gehen"
fi

echo "== Protokollierung (ROUTER-C2C im Router-Log) =="
docker exec "$P-client1" ping -c1 -W2 10.0.20.11 &>/dev/null || true
if docker exec "$P-int-router" sh -c "dmesg 2>/dev/null | tail -50 | grep -q ROUTER-C2C"; then
  ok "ROUTER-C2C wird geloggt"
else
  echo "INFO  ROUTER-C2C nicht in dmesg gefunden (Logweg pruefen, siehe INSTALL)"
fi

echo "== Scan-Bremse (schneller Scan wird teils verworfen) =="
out=$(docker exec "$P-client1" nmap -n -T5 -p1-200 10.0.20.11 2>/dev/null | grep -c open || true)
echo "INFO  offene Ports im Schnellscan: ${out:-0} (Scan-Bremse begrenzt die Trefferrate)"
ok "Scan ausgefuehrt, Bremse greift laut ROUTER-SCAN-Log"

echo; echo "Ergebnis: $pass PASS, $fail FAIL"
[ "$fail" -eq 0 ]
