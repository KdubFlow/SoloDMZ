#!/usr/bin/env bash
# =============================================================================
#  sun-responder (SF-14) - automatische, temporaere Sperre nach Alarm hoher Guete.
#  Laeuft auf der VM (nicht im Container), liest das IDS/IPS-eve.json und traegt
#  die Angreifer-IP fuer 10 Minuten in die nftables-Sperrliste der passenden
#  Firewall ein. Eigene Systeme sind per Allowlist geschuetzt.
#
#  Aufruf: sudo ./scripts/responder.sh
# =============================================================================
set -uo pipefail
P=clab-solodmz
EVE=/var/log/sun/ids/eve.json
TIMEOUT="10m"

# SIDs, die eine Sperre ausloesen duerfen (eindeutige Alarme)
TRIGGER_SIDS="1000001 1000002 1000003 1100001 1100003 1100004"

# Allowlist: diese Quellen werden NIE gesperrt
in_allowlist() {
  case "$1" in
    198.51.100.*|203.0.113.1|10.0.30.*|192.168.250.*) return 0 ;;
    *) return 1 ;;
  esac
}

# Interne Quelle -> auch Inner-FW und Int-Router sperren; externe -> Edge-FW
block() {
  local ip="$1"
  if in_allowlist "$ip"; then return; fi
  case "$ip" in
    10.0.20.*)
      docker exec "$P-inner-fw"   nft add element inet inner  blocklist "{ $ip timeout $TIMEOUT }" 2>/dev/null
      docker exec "$P-int-router" nft add element inet router blocklist "{ $ip timeout $TIMEOUT }" 2>/dev/null
      ;;
    *)
      docker exec "$P-edge-fw"    nft add element inet edge   blocklist "{ $ip timeout $TIMEOUT }" 2>/dev/null
      ;;
  esac
  mkdir -p /var/log/sun/responder
  echo "$(date -Is) RESPONDER BLOCK $ip ($TIMEOUT)" | tee -a /var/log/sun/responder/responder.log
}

echo "sun-responder laeuft. Ausloesende SIDs: $TRIGGER_SIDS"
[ -f "$EVE" ] || { echo "Warte auf $EVE ..."; while [ ! -f "$EVE" ]; do sleep 1; done; }

tail -F "$EVE" | while read -r line; do
  sid=$(echo "$line" | jq -r 'select(.event_type=="alert") | .alert.signature_id // empty' 2>/dev/null)
  [ -z "$sid" ] && continue
  case " $TRIGGER_SIDS " in *" $sid "*) ;; *) continue ;; esac
  src=$(echo "$line" | jq -r '.src_ip // empty' 2>/dev/null)
  [ -n "$src" ] && block "$src"
done
