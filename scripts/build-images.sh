#!/usr/bin/env bash
# Baut die eigenen Images mit festen Versions-Tags (reproduzierbar, kein "latest", SF-12).
set -euo pipefail
cd "$(dirname "$0")/.."

docker build -t sun/net:1.0    images/sun-net
docker build -t sun/client:1.0 images/sun-client
docker build -t sun/web:1.0    images/sun-web
docker build -t sun/ips:1.0    images/sun-ips

echo "Images gebaut: sun/net:1.0, sun/client:1.0, sun/web:1.0, sun/ips:1.0"
