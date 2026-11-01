#!/usr/bin/env bash
# Baut die Laborumgebung vollstaendig ab.
# Aufruf: sudo ./scripts/destroy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$EUID" -eq 0 ] || { echo "Bitte mit sudo ausfuehren." >&2; exit 1; }

./scripts/mirror.sh down 2>/dev/null || true
containerlab destroy -t topo/dmz.clab.yml --cleanup || true
./scripts/bridges.sh down
echo "Abbau abgeschlossen."
