# SoloDMZ

Sichere Unternehmensnetzwerk-DMZ für das Modul **Sichere Unternehmensnetzwerke (SUN)**.
Aufbau mit **Containerlab** auf einer Debian-VM: präventive, detektive und reaktive
Maßnahmen rund um einen unternehmenskritischen Webserver, mit sichtbarem SOC-Nachweis.

> Dieses Repo ist die technische Umsetzung des **TOE** (Target of Evaluation,
> Interface-Variante B). Die begründende Dokumentation liegt dort; `docs/TOE-Kurzfassung.md`
> fasst sie zusammen.

## Architektur in einem Satz
Jeder Dienst liegt in einem eigenen Segment, jeder Weg zwischen zwei Systemen führt
durch eine Firewall, und kein Segment dient als Durchgang für fremden Verkehr.

- **3 Firewalls:** `edge-fw` (Perimeter, +IPS 1), `inner-fw` (+IPS 2), `backend-fw` (vor dem SOC)
- **DMZ (je eigenes /28):** `rproxy`+WAF, `web`, `vpn-gw`, `honeypot`
- **Intern:** `int-router` + `client1`/`client2` (Port-Isolation)
- **Backend/SOC:** `siem-loki`, `siem-grafana`, `siem-alloy` (Logs out-of-band über die VM)
- **Zweigstelle:** `ro-gw` + `ro-client1`, Site-to-Site-VPN (Full Tunnel)
- **Sensorik:** passives `ids` an 8 Spiegelpunkten

## Schnellstart (auf der VM)
```bash
sudo ./scripts/deploy.sh          # Images, Bridges, Container, Netz, Firewalls
# danach Dienste einrichten: docs/INSTALL.md Abschnitt 5-9 (WAF, VPN, IDS/IPS, SIEM)
sudo ./tests/00_topologie.sh      # Verkabelung
sudo ./tests/01_segmentation.sh   # Kommunikationsmatrix
sudo ./scripts/destroy.sh         # alles abbauen
```

## Verzeichnisse
| Ordner | Inhalt |
|---|---|
| `topo/` | Containerlab-Topologie (Verkabelung) |
| `images/` | eigene Images (sun/net, sun/client, sun/web, sun/ips) |
| `scripts/` | deploy, destroy, configure-net, bridges, mirror, responder, demo-reset |
| `configs/` | Firewall-Regeln (nftables), WAF, VPN, IDS/IPS, SIEM |
| `tests/` | Funktionsnachweise (Segmentierung, WAF, Lateral, Client↔Client) |
| `attacks/` | Nachweis-Skripte der zwei Angriffsketten (gegen das eigene Labor) |
| `docs/` | Installationsanleitung und TOE-Kurzfassung |

## Status der Umsetzung
Stufe 1 (Pflichtkern) ist in diesem Repo als Gerüst und lauffähige Infrastruktur
angelegt. Dienste (WAF-Feinkonfiguration, WireGuard-Schlüssel, Suricata-Start,
SIEM-Dashboards) werden gemäß `docs/INSTALL.md` auf der VM eingerichtet und dort
getestet. Erst nach erfolgreichem Test gilt eine Funktion als nachgewiesen.

## Hilfsmittel
Erstellt mit Unterstützung von Claude (KI) als Beratung und Code-Gerüst;
Umsetzung und Tests durch das Team. Siehe Quellen-/Hilfsmittelverzeichnis der Doku.
