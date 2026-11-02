#!/usr/bin/env bash
# Startet die komplette Laborumgebung.
# Aufruf: sudo ./scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$EUID" -eq 0 ] || { echo "Bitte mit sudo ausfuehren." >&2; exit 1; }

# 1. Eigene Images bauen, falls noetig
for img in sun/net:1.0 sun/client:1.0 sun/web:1.0 sun/ips:1.0; do
  docker image inspect "$img" &>/dev/null || { ./scripts/build-images.sh; break; }
done

# 2. Bridges anlegen
./scripts/bridges.sh up

# 3. Container und Verkabelung
containerlab deploy -t topo/dmz.clab.yml --reconfigure

# 4. Adressen, Routen, Isolation, Spiegelung, Firewall-Regeln
./scripts/configure-net.sh

# 4b. Container NICHT automatisch neu starten lassen. Schuetzt vor einem Kernel-Lockup,
#     falls die VM mit laufendem Labor neu gebootet wird (die Bridges sind dann weg).
#     Beim naechsten Boot bleibt alles ruhig, bis bewusst wieder deploy.sh laeuft.
docker update --restart=no $(docker ps -aq --filter "name=clab-solodmz") >/dev/null 2>&1 || true

# 5. Dienste konfigurieren (WAF/VPN/IDS/IPS/SIEM) - siehe docs/INSTALL.md
echo
echo "Basis steht. Dienste einrichten: docs/INSTALL.md Abschnitt 5-9."
echo "Pruefen: sudo ./tests/00_topologie.sh && sudo ./tests/01_segmentation.sh"
