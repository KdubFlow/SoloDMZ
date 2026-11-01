#!/usr/bin/env bash
# T03 - WAF (SF-05): harmlose Angriffsproben gegen die EIGENE WAF, erwartet 403.
# Dies ist ein Funktionstest der eigenen Abwehr, keine Angriffskampagne.
# Aufruf: sudo ./tests/03_waf.sh [quelle]   (quelle: client1 | ang-internet)
set -uo pipefail
P=clab-solodmz
SRC="${1:-client1}"
[ "$SRC" = "ang-internet" ] && URL="https://198.51.100.2" || URL="https://10.0.10.2"
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }

code(){ docker exec "$P-$SRC" curl -sk -o /dev/null -w '%{http_code}' --max-time 5 "$1" 2>/dev/null; }

echo "== Legitimer Zugriff (erwartet 200/301/302) =="
c=$(code "$URL/"); case "$c" in 200|301|302) ok "Startseite: $c";; *) nok "Startseite: $c";; esac

echo "== Angriffsproben (erwartet 403) =="
for probe in \
  "/?id=1'%20OR%20'1'='1" \
  "/?q=<script>alert(1)</script>" \
  "/?file=../../../../etc/passwd" \
  "/?cmd=;cat%20/etc/passwd" ; do
  c=$(code "$URL$probe")
  [ "$c" = "403" ] && ok "geblockt ($c): $probe" || nok "NICHT geblockt ($c): $probe"
done

echo; echo "Ergebnis: $pass PASS, $fail FAIL"
echo "Hinweis: Verschleierte Varianten (Kette B2) ggf. erst ab PARANOIA=2 erkannt."
[ "$fail" -eq 0 ]
