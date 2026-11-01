# Angriffs-Demos (Nachweis der Abwehr)

Diese Skripte erzeugen **Testverkehr gegen das eigene Labor**, um zu zeigen, dass
die Schutzmaßnahmen greifen. Sie sind bewusst schlicht und benutzen
Standardwerkzeuge (nmap, curl). Es sind **keine** fertigen Exploits oder
Schadprogramme: Jeder Schritt soll an einer Abwehr scheitern und dabei eine Spur
im SOC hinterlassen.

Die aufwendige Detektions- und Korrelationslogik (eigene Suricata-Regeln,
SIEM-Zeitleiste, Alarmregeln) gehört zu **Person B** und wird dort ausgearbeitet.
Hier stehen nur die auslösenden Testschritte und ihre erwartete Abwehr.

## Kette A - intern (Phishing bis Datenabfluss)
Quelle: `client1`. Ziel: Daten von `client2` ins Internet schaffen.

| Schritt | Testaktion | Erwartete Abwehr / Spur |
|---|---|---|
| A1 | `client1` lädt ein Skript vom Angreifer-Host | IDS/IPS-Signatur „Skript-Download“ (SID 1000004/1100005) |
| A2 | regelmäßige Verbindung auf 443 ohne TLS | Suricata „Port 443 ohne TLS“ (SID 1000003/1100004) |
| A3 | langsamer Scan im Client-Netz | `ROUTER-C2C`-Logs, SIEM-Korrelation |
| A4 | Abruf der Dateifreigabe auf `client2` | `ROUTER-C2C`, IDS |
| A5 | großer Upload ins Internet | **Exfil-Bremse** (SF-16) kappt ab 20 MB, SIEM-Mengenalarm, SF-14 sperrt |

`kette-a.sh` erzeugt diese Schritte als Testverkehr (siehe Kommentare im Skript).

## Kette B - extern (verschleierter Webangriff bis Ausbruch)
Quelle: `ang-internet`, später angenommener übernommener `rproxy`.

| Schritt | Testaktion | Erwartete Abwehr / Spur |
|---|---|---|
| B1 | Portscan auf die öffentliche IP | nur 4 Ports offen, `EDGE-DROP`, IDS Uplink |
| B2 | SQLi-Proben (auch verschleiert) gegen die WAF | WAF 403 (Test 03) |
| B3 | angenommen: `rproxy` übernommen (`docker exec`) | Ausgangslage |
| B4 | Scan auf VPN-GW, Client-, Backend-Netz | `EDGE-DROP`, alle blockiert |
| B5 | Werkzeug nachladen / Reverse Shell ins Internet | `EDGE-DROP` (kein Egress außer F13) |
| B6 | Command Injection an `web` über den erlaubten Pfad | IPS 1 verwirft (SID 1100003) |

`kette-b.sh` führt B1, B2, B4, B5 als Testverkehr aus und prüft, dass alles scheitert.

## Vor jeder Demo
`sudo ./scripts/demo-reset.sh` ausführen, damit Sperrlisten und Zähler zurückgesetzt sind.
