#!/usr/bin/env bash
# T18 - TLS am Reverse-Proxy (SF-06): moderne Protokolle an, altes TLS aus,
#       Zertifikat wird praesentiert. Geprueft vom Client aus gegen rproxy (443).
# Aufruf: sudo ./tests/18_tls.sh
set -uo pipefail
P=clab-solodmz
RP=10.0.10.2
pass=0; fail=0
ok(){  echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }
# curl vom Client gegen den Proxy, mit erzwungener TLS-Version
c(){ docker exec "$P-client1" curl -sk --max-time 5 "$@" "https://$RP/" -o /dev/null; }

echo "== Moderne TLS-Versionen (erwartet: Verbindung) =="
if c --tlsv1.3 --tls-max 1.3; then ok "TLS 1.3 funktioniert"; else echo "INFO  TLS 1.3 nicht verfuegbar (dann traegt TLS 1.2)"; fi
if c --tlsv1.2 --tls-max 1.2; then ok "TLS 1.2 funktioniert"; else nok "TLS 1.2 fehlgeschlagen"; fi

echo "== Altes TLS 1.0 (erwartet: abgelehnt) =="
if c --tlsv1.0 --tls-max 1.0; then nok "TLS 1.0 wird akzeptiert (sollte aus sein)"; else ok "TLS 1.0 wird abgelehnt"; fi

echo "== Zertifikat =="
cert=$(docker exec "$P-client1" sh -c "echo | openssl s_client -connect $RP:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null")
if [ -n "$cert" ]; then
  ok "Zertifikat wird praesentiert"
  echo "$cert" | sed 's/^/      /'
else
  nok "kein Zertifikat erhalten"
fi

echo "== HTTP auf Port 80 (erwartet: Umleitung auf HTTPS) =="
code=$(docker exec "$P-client1" curl -s --max-time 5 -o /dev/null -w '%{http_code}' "http://$RP/" 2>/dev/null)
case "$code" in
  301|302|308) ok "HTTP leitet auf HTTPS um ($code)";;
  *) echo "INFO  HTTP antwortet mit ${code:-?} statt einer Umleitung - ggf. im Proxy aktivieren";;
esac

echo
echo "Ergebnis: $pass PASS, $fail FAIL"
[ "$fail" -eq 0 ]
