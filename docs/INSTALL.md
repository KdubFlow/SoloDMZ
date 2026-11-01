# Installationsanleitung SoloDMZ

## 0. Voraussetzungen (VM)
- Debian 13, 2 vCPU, 6 GB RAM, 20 GB Platte, 2 GB Swap
- Docker, Containerlab, `nsenter`, `tc` (iproute2), `jq`
- Log-Verzeichnis anlegen: `sudo mkdir -p /var/log/sun/{edge-fw,inner-fw,backend-fw,int-router,ids,rproxy,web,vpn-gw,honeypot,responder}`

## 1. Images und Basis
```bash
sudo ./scripts/deploy.sh
```
Das baut die Images, legt die Bridges an, startet die 21 Container und setzt per
`configure-net.sh` Adressen, Routen, Port-Isolation, Spiegelung und die
Firewall-Regeln. Danach:
```bash
sudo ./tests/00_topologie.sh
sudo ./tests/01_segmentation.sh
```

## 2. Firewalls prüfen
Die Regeln liegen in `configs/<fw>/nftables.conf` und werden automatisch geladen.
Kontrolle: `docker exec clab-solodmz-edge-fw nft list ruleset | less`

## 3. Logs aus den Namespaces auf die VM
Damit Firewall-Logs (`*-DROP`, `*-NEW`) und Suricata-eve.json auf der VM landen:
- Firewall-Logs: `nftables`-`log`-Eintrag geht ins Kernel-Log; auf der VM
  `net.netfilter.nf_log_all_netns=1` setzen und das Journal mit Alloy einlesen.
- Dienst-Logs: die Container nach `/var/log/sun/<name>/` schreiben lassen
  (Bind-Mount in `topo/dmz.clab.yml` je Knoten via `binds:` ergänzen).

## 4. Port-Isolation / Client↔Client
Bereits von `configure-net.sh` gesetzt (`isolated on`, `proxy_arp_pvlan=1`).
Nachweis: `sudo ./tests/09_client_client.sh`

## 5. WAF (rproxy)
Env-Variablen stehen im Topologie-Knoten (`BACKEND`, `PARANOIA`, `MODSEC_RULE_ENGINE`).
Audit-Log nach `/var/log/sun/rproxy/` leiten. Test:
```bash
sudo ./tests/03_waf.sh client1
sudo ./tests/03_waf.sh ang-internet
```
Für die verschleierten Angriffe aus Kette B ggf. `PARANOIA=2` setzen und neu testen.

## 6. VPN (Site-to-Site)
```bash
# Schlüssel erzeugen (auf vpn-gw und ro-gw je einmal)
docker exec clab-solodmz-vpn-gw sh -c 'wg genkey | tee /priv | wg pubkey > /pub'
docker exec clab-solodmz-ro-gw  sh -c 'wg genkey | tee /priv | wg pubkey > /pub'
```
`configs/vpn-gw/wg0.conf.example` und `configs/ro-gw/wg0.conf.example` mit den
öffentlichen Schlüsseln ausfüllen, nach `/etc/wireguard/wg0.conf` kopieren,
`wg-quick up wg0` starten. Auf `ro-gw` die Standardroute über `wg0` setzen
(Full Tunnel). **Schlüssel nicht committen** (siehe `.gitignore`). Test: `tests/10_vpn.sh` (Person A, folgt).

## 7. IDS (passiv)
Im `ids`-Container Suricata auf den 8 gespiegelten Interfaces (eth1–eth8) im
af-packet-Modus starten, Regeln aus `configs/ids/local.rules`, Ausgabe als
eve.json nach `/var/log/sun/ids/`. Spiegelung ist bereits aktiv
(`scripts/mirror.sh`, von `configure-net.sh` aufgerufen).

## 8. IPS 1/2 (inline, fail-open)
Auf `edge-fw` und `inner-fw`:
```bash
docker cp configs/ips/nfqueue.nft clab-solodmz-edge-fw:/etc/nfqueue.nft
docker exec clab-solodmz-edge-fw nft -f /etc/nfqueue.nft
# Suricata im selben Namespace (ips-edge) inline starten:
docker exec clab-solodmz-ips-edge suricata -q 0 --set nfq.fail-open=true \
  -S /etc/suricata/local-ips.rules -l /var/log/sun/ids/
```
`configs/ips/local-ips.rules` zuerst mit `alert` testen, dann auf `drop` stellen
(IPS 2 nur mit dem kleinen eigenen Regelsatz). Analog für `inner-fw`/`ips-inner`.

## 9. SIEM (Alloy → Loki → Grafana)
- `configs/siem/loki-config.yaml` in `siem-loki` nach `/etc/loki/local-config.yaml`
- `configs/siem/alloy-config.alloy` in `siem-alloy`, Verzeichnis `/var/log/sun` read-only mounten
- `configs/siem/grafana/datasource.yaml` nach `/etc/grafana/provisioning/datasources/`
- Grafana-Admin-Passwort über `GF_SECURITY_ADMIN_PASSWORD` setzen (nicht ins Repo).
- Zugriff auf das Dashboard über die VM (Management-Link 192.168.250.0/30).
- 1-Sekunden-Kette messen: Angriff auslösen, per Loki-API den Eintrag abfragen, Zeit stoppen.

## 10. Reaktion (SF-14)
```bash
sudo ./scripts/responder.sh   # liest IDS-eve.json, sperrt Angreifer-IPs 10 min
```

## 11. Honeypot
`honeypot` ist als Platzhalter (`sun/net`) angelegt. Für einen echten SSH-Honeypot
Cowrie im Container installieren (Port 2222) und Logs nach `/var/log/sun/honeypot/`
schreiben. DNAT 22→2222 ist in der Edge-FW bereits gesetzt (F04).

## Vor der Demo
```bash
sudo ./scripts/demo-reset.sh
```
