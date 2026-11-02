# Roter Leitfaden – SoloDMZ (SUN Programmentwurf)

> Stand: 2. November 2026 · Repo: `soloDMZ/solodmz` · VM: Debian, 2–3 vCPU / 6 GB / 20 GB
> Dieser Leitfaden ist die zentrale Übersicht: Was ist fertig, was fehlt noch (getrennt
> nach Person A und Person B), und was bleibt ganz am Ende übrig.

---

## 1. Teil Person A – FERTIG und nachgewiesen

Alle Präventionsmaßnahmen meiner Rolle sind auf der VM gebaut, konfiguriert und durch
automatisierte Tests belegt. Die Testprotokolle liegen unter `docs/testprotokolle/`.

| Bereich | Umsetzung | Nachweis (Test) | Status |
|---|---|---|---|
| Topologie / Segmentierung | 21 Container, 10 Bridges, Interface-pro-Dienst | `00_topologie.sh` (28/28) | ✓ |
| Firewalls (default-deny) | Edge-FW, Inner-FW, Backend-FW – nftables, NAT, Sperrliste | `01_segmentation.sh` (11/11) | ✓ |
| WAF / Reverse Proxy | ModSecurity CRS, TLS-Terminierung | `03_waf.sh` (5/5) | ✓ |
| Lateral / Egress / Web-Isolation | Exfil-Bremse, Web darf nicht raus, Client-Isolation | `07_lateral.sh` (9/9) | ✓ |
| VPN (Site-to-Site) | WireGuard Full-Tunnel Zentrale ↔ Zweigstelle | `10_vpn.sh` (3/3) | ✓ |
| TLS am Proxy | TLS 1.3/1.2 an, TLS 1.0 aus, Zertifikat | `18_tls.sh` (4/0) | ✓ |

**Fazit:** Der technische Präventions-Anteil von Person A ist vollständig und verteidigbar.

### Was genau Person A abdeckt (zum Verteidigen)
- **Architektur:** Back-to-Back / Interface-pro-Dienst; extern RFC 5737, intern RFC 1918; Defense-in-Depth, Assume-Breach.
- **Perimeter (Edge-FW):** Default-Deny-Forward, DNAT (443→Proxy:8443, 80→Proxy:8080, 51820→VPN, 22→Honeypot), SNAT, Flows F01–F09/F13/F14, automatisch ablaufende Sperrliste.
- **Innen-FW:** F07–F09, Exfil-Bremse (`ct original bytes > 20 MB → drop`), Backend-Link gekapselt.
- **Interner Router:** überwachte Client↔Client-Kommunikation (Scan-Meter, Sperrliste, Alarm) via Proxy-ARP – bleibt möglich, aber kontrolliert.
- **Reverse Proxy + WAF:** einziger Web-Eingang, TLS endet hier, HTTP zum Web nur geprüft weiter.
- **VPN:** WireGuard Full-Tunnel, Zweigstelle erreicht Firmennetz ausschließlich durch den Tunnel.
- **Honeypot:** Köder auf Port 22 (SSH), zieht Scans vom Produktivnetz weg.

---

## 2. Was ich (Person A) jetzt noch abschließe – damit alles in einem Ordner liegt

- [ ] **TLS-Test + Protokolle committen** (siehe Befehl unten).
- [ ] **Diesen Leitfaden committen** (`docs/LEITFADEN.md`).
- [ ] *(optional)* `.gitignore` anpassen, damit Testprotokolle versioniert werden:
      Zeile `!docs/testprotokolle/*.log` ergänzen.
- [ ] *(optional, Kür)* HTTP→HTTPS-Umleitung im Proxy aktivieren. Test 18 meldet dies
      aktuell als `INFO`, nicht als Fehler – kein Muss für die Prävention.

Danach ist der Ordner (= das Repo) der vollständige Abgabestand für Person A:
Architektur, Firewall-Regeln, VPN, WAF/TLS, Tests, Protokolle, Doku.

---

## 3. OFFEN – Teil Person B (Erkennung & Reaktion)

Klar getrennt von Person A. Die **Bausteine stehen schon im Repo** (Configs vorhanden),
müssen aber scharfgeschaltet, mit Regeln versehen und nachgewiesen werden.

| # | Aufgabe | Vorhandene Basis im Repo | Nachweisziel |
|---|---|---|---|
| B1 | **IDS (Suricata passiv)** scharfschalten | `configs/ids/local.rules`, Port-Spiegelung | sieht Angriff, erzeugt Alert |
| B2 | **IPS inline (NFQUEUE, fail-open)** scharfschalten – ips-edge & ips-inner | `configs/ips/local-ips.rules`, `nfqueue.nft` | blockt Angriff aktiv |
| B3 | **SIEM-Pipeline** (Grafana/Loki/Alloy) | `configs/siem/*` | Logs laufen zentral ein |
| B4 | **SOC-Dashboards** | – (neu) | Angriffe sichtbar in einem Board |
| B5 | **Auto-Block-Responder (SF-14)** | `scripts/responder.sh` | füllt Edge-FW-Sperrliste automatisch |
| B6 | **Honeypot interaktiv (Cowrie)** statt nur Köder | Honeypot-Container vorhanden | protokolliert Angreifer-Eingaben |
| B7 | **Horizontale Überwachung** Client↔Client | int-router-Logs vorhanden | Anomalie → SOC-Alarm |
| B8 | **1-Sekunden-Nachweis** (Erkennungslatenz) | Logs/Zeitstempel | Angriff → Alert < 1 s messbar |

---

## 4. OFFEN am Ende – GEMEINSAM (erst wenn Person B fertig ist)

Das sind die Schritte, die **beide Teile zusammenführen** und ohne Person B nicht gehen:

1. **Angriffsketten ausführen** (verkettet, keine Supply-Chain):
   - *Kette A:* Phishing-Einstieg → Lateral Movement → Massen-Exfiltration.
   - *Kette B:* zweite verkettete Kette (zweiter Einstiegspunkt / Ziel).
   - *(mind. 3 Cyberangriffe gesamt gefordert).*
2. **End-to-End-Nachweis:** Angriff → Erkennung (IDS) → aktive Abwehr (IPS/Auto-Block) → sichtbar im SOC.
3. **Erkennung < 1 Sekunde** messen und dokumentieren (Zeitstempel Angriff vs. Alert).
4. **Gesamtdoku zusammenführen:** Person A (Prävention) + Person B (Detektion/Reaktion) in ein Dokument.
5. **Demo/Präsentation** vorbereiten und einmal komplett durchspielen (Reset-Skript: `scripts/demo-reset.sh`).

---

## 5. Betrieb – damit nichts hängt

- **Starten:** `sudo ./scripts/deploy.sh` danach `sudo ./scripts/vpn-up.sh`.
- **Prüfen:** `sudo ./tests/00_topologie.sh` (und weitere Tests nach Bedarf).
- **Abbauen – IMMER vor dem Herunterfahren der VM:** `sudo ./scripts/destroy.sh`.
- **Nur EIN Labor gleichzeitig** laufen lassen (6 GB RAM / wenige Kerne). Vor dem Start
  eines anderen Labors das laufende zuerst mit `destroy.sh` abbauen.
- `deploy.sh` setzt bewusst `--restart=no` auf alle Container, damit ein Reboot der VM
  mit laufendem Labor **keinen Kernel-Lockup** auslöst.

---

## 6. Rückbau & Wiederherstellung der ERSTEN DMZ

**Kurz: Ja, problemlos – solange die Dateien der ersten DMZ erhalten bleiben.**

- `destroy.sh` entfernt nur die **laufenden Container**, nicht die Dateien. Containerlab
  ist deklarativ: aus Topologie + Configs wird jederzeit derselbe Soll-Zustand neu gebaut.
- Die erste DMZ kannst du also jederzeit wieder hochfahren, **wenn ihr Projektordner /
  ihr eigenes Repo noch existiert** (lokal auf der VM oder in GitHub). Aus GitHub einfach
  neu klonen/pullen und dort `deploy` ausführen.
- **Reihenfolge beachten:** Immer nur ein Labor gleichzeitig. Vor dem Start der ersten DMZ
  zuerst `sudo ./scripts/destroy.sh` in SoloDMZ ausführen (sonst Bridge-/IP-/Namenskonflikte).
- **Was zurückkommt** ist der **Soll-Zustand aus den Config-Dateien** – nicht etwaige
  Live-Änderungen, die nur im Container gemacht und nie in eine Config gespeichert wurden.
- **Exakter Gesamt-Snapshot gewünscht?** Dann über **VirtualBox-Snapshot** absichern: der
  friert die komplette VM (beide Labor-Ordner + allem) auf genau diesen Moment ein und
  stellt alles 1:1 wieder her – die zuverlässigste „Zeitmaschine".

---

## 7. Repo-Überblick (Ordner = Abgabe)

```
solodmz/
├─ topo/dmz.clab.yml            # Topologie: Container + Verkabelung
├─ configs/                     # Firewalls, WAF, VPN, IDS, IPS, SIEM
│  ├─ edge-fw/ inner-fw/ backend-fw/ int-router/ ro-gw/
│  ├─ ids/ ips/ siem/
├─ scripts/                     # deploy, destroy, bridges, configure-net,
│  │                            # vpn-up, mirror, responder, demo-reset
├─ tests/                       # 00,01,03,07,10,18 (Person A – alle grün)
└─ docs/
   ├─ LEITFADEN.md              # dieses Dokument
   └─ testprotokolle/           # Belege der Testläufe
```
