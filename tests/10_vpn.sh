#!/usr/bin/env bash
# T10 - VPN (SF-07): Tunnel steht, Zweigstelle erreicht das Firmennetz nur darueber.
# Aufruf: sudo ./tests/10_vpn.sh
set -uo pipefail
P=clab-solodmz
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }

echo "== Tunnel-Status =="
hs=$(docker exec "$P-vpn-gw" wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}')
if [ -n "${hs:-}" ] && [ "${hs:-0}" -gt 0 ] 2>/dev/null; then
  ok "WireGuard-Handshake vorhanden"
else
  nok "kein Handshake (Tunnel nicht aktiv?)"
fi

echo "== Zweigstelle -> Firmennetz (durch den Tunnel) =="
if docker exec "$P-ro-client1" curl -sk --max-time 6 https://10.0.10.2/ >/dev/null 2>&1; then
  ok "ro-client1 -> rproxy/WAF (F06, ueber Tunnel)"
else
  nok "ro-client1 -> rproxy (sollte ueber Tunnel gehen)"
fi
if docker exec "$P-ro-client1" ping -c1 -W3 10.0.20.10 >/dev/null 2>&1; then
  ok "ro-client1 -> client1 (F07, ueber Tunnel)"
else
  nok "ro-client1 -> client1 (sollte ueber Tunnel gehen)"
fi

echo
echo "Ergebnis: $pass PASS, $fail FAIL"
[ "$pass" -ge 2 ]
