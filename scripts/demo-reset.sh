#!/usr/bin/env bash
# Setzt den Zustand zwischen zwei Demo-Durchlaeufen zurueck: Sperrlisten leeren,
# Verbindungstabellen loeschen, Logs rotieren. Aufruf: sudo ./scripts/demo-reset.sh
set -uo pipefail
P=clab-solodmz

echo "== Sperrlisten leeren =="
docker exec "$P-edge-fw"    nft flush set inet edge   blocklist 2>/dev/null || true
docker exec "$P-inner-fw"   nft flush set inet inner  blocklist 2>/dev/null || true
docker exec "$P-int-router" nft flush set inet router blocklist 2>/dev/null || true

echo "== Verbindungstabellen (conntrack) leeren =="
for fw in edge-fw inner-fw backend-fw int-router ro-gw; do
  docker exec "$P-$fw" conntrack -F 2>/dev/null || true
done

echo "== Logs rotieren =="
if [ -d /var/log/sun ]; then
  ts=$(date +%Y%m%d-%H%M%S)
  mkdir -p "/var/log/sun/_archiv/$ts"
  find /var/log/sun -maxdepth 2 -type f \( -name '*.log' -o -name '*.json' \) \
    -not -path '*/_archiv/*' -exec sh -c 'cp "$1" "/var/log/sun/_archiv/'"$ts"'/" && : > "$1"' _ {} \;
fi
echo "Reset abgeschlossen."
