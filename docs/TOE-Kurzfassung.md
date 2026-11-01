# TOE-Kurzfassung (SoloDMZ, Interface-Variante B)

Diese Kurzfassung verbindet die Doku (TOE) mit dem Code. Die vollständige
Begründung, das Bedrohungsmodell und die Restrisiken stehen im TOE-Dokument.

## Adressplan
| Netz | Bereich | Teilnehmer |
|---|---|---|
| Internet | 203.0.113.0/24 | isp-router .1, ang-internet .10, inet-server .30, ro-gw .40 |
| Zweigstelle | 10.50.0.0/24 | ro-gw .1, ro-client1 .10 |
| Uplink | 198.51.100.0/30 | isp-router .1, edge-fw .2 |
| F-DMZ | 10.0.10.0/28 | edge-fw .1, rproxy .2 |
| B1-DMZ | 10.0.10.16/28 | edge-fw .17, web .18 |
| B2-DMZ | 10.0.10.32/28 | edge-fw .33, vpn-gw .34 |
| H-DMZ | 10.0.10.48/28 | edge-fw .49, honeypot .50 |
| Transit | 10.0.255.0/30 | edge-fw .1, inner-fw .2 |
| Router-Link | 10.0.254.0/30 | inner-fw .1, int-router .2 |
| Backend-Link | 10.0.253.0/30 | inner-fw .1, backend-fw .2 |
| Client | 10.0.20.0/24 | int-router .1, client1 .10, client2 .11 |
| Backend | 10.0.30.0/24 | backend-fw .1, siem-grafana .10, siem-loki .11, siem-alloy .12 |
| VPN-Tunnel | 10.9.0.0/30 | vpn-gw .1, ro-gw .2 |

## Erlaubte Flüsse (Default-Deny sonst)
F01 Internet→Web(443) · F02 Internet→Web(80→301) · F03 Zweigstelle→VPN · F04 Internet→Honeypot ·
F05 rproxy→web(80) · F06 Zweigstelle→rproxy(443) · F07 Zweigstelle→Client · F08 Client→Internet ·
F09 Client→rproxy · F10 SOC intern · F11 VM→Grafana · F12 Client↔Client (über Router) ·
F13 DMZ→inet-server · F14 Zweigstelle→Internet (Full Tunnel)

## Sicherheitsfunktionen → Dateien
| SF | Umsetzung im Repo |
|---|---|
| SF-01/02/04/13 Firewall, NAT, Anti-Spoofing, Egress | `configs/*/nftables.conf` |
| SF-05/06 WAF, TLS | `configs/rproxy/`, Topologie-Env |
| SF-07 VPN Site-to-Site | `configs/vpn-gw/`, `configs/ro-gw/` |
| SF-08 IPS inline, fail-open | `configs/ips/` |
| SF-09 IDS passiv, 8 Spiegel | `configs/ids/`, `scripts/mirror.sh` |
| SF-10 Honeypot | `honeypot`-Knoten, INSTALL §11 |
| SF-11 SIEM out-of-band | `configs/siem/` |
| SF-12 Container-Härtung | `images/`, `network-mode: none` |
| SF-14 automatische Sperre | `scripts/responder.sh`, `blocklist`-Sets |
| SF-15 Client-Isolation | `configure-net.sh`, `configs/int-router/` |
| SF-16 Exfil-Bremse | `configs/inner-fw/nftables.conf` |

## Tests
`00` Verkabelung · `01` Matrix · `03` WAF · `07` Lateral/Egress/Web-only · `09` Client↔Client.
Weitere (02 Portscan, 04 1-Sekunde, 06 Totmannschalter, 08 Korrelation) liegen bei Person B.
