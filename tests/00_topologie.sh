#!/usr/bin/env bash
# T00 - Verkabelung: Interfaces je Container (kein eth0), Bridge-Mitglieder.
# Aufruf: sudo ./tests/00_topologie.sh
set -uo pipefail
[ "$EUID" -eq 0 ] || { echo "Bitte mit sudo." >&2; exit 1; }
P=clab-solodmz
pass=0; fail=0
ok(){ echo "PASS  $*"; pass=$((pass+1)); }
nok(){ echo "FAIL  $*"; fail=$((fail+1)); }
norm(){ tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ' | sed 's/ $//'; }

ifaces(){
  local pid; pid=$(docker inspect -f '{{.State.Pid}}' "$P-$1" 2>/dev/null) || return 1
  nsenter -t "$pid" -n ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | cut -d@ -f1 \
    | grep -E '^eth' | norm
}
node(){ local n=$1; shift; local soll ist; soll=$(echo "$*"|norm); ist=$(ifaces "$n") \
  || { nok "$n laeuft nicht"; return; }; [ "$ist" = "$soll" ] && ok "$n: $ist" || nok "$n ist=[$ist] soll=[$soll]"; }
bridge(){ local b=$1; shift; local soll ist; soll=$(echo "$*"|norm); \
  ist=$(ls "/sys/class/net/$b/brif" 2>/dev/null|norm); [ "$ist" = "$soll" ] && ok "$b: $ist" || nok "$b ist=[$ist] soll=[$soll]"; }

echo "== Interfaces =="
node isp-router eth1 eth2
node ang-internet eth1
node inet-server eth1
node ro-gw eth1 eth2
node ro-client1 eth1
node edge-fw eth1 eth2 eth3 eth4 eth5 eth6
node rproxy eth1;  node web eth1;  node vpn-gw eth1;  node honeypot eth1
node inner-fw eth1 eth2 eth3
node int-router eth1 eth2
node client1 eth1;  node client2 eth1
node backend-fw eth1 eth2
node siem-loki eth1;  node siem-grafana eth1;  node siem-alloy eth1

echo; echo "== Bridges =="
bridge br-internet inet-isp inet-ang inet-srv inet-rogw
bridge br-remote rem-gw rem-c1
bridge br-uplink upl-isp upl-edge
bridge br-fdmz fdmz-edge fdmz-rpx
bridge br-b1dmz b1-edge b1-web
bridge br-b2dmz b2-edge b2-vpn
bridge br-hdmz hdmz-edge hdmz-hp
bridge br-transit tr-edge tr-inner
bridge br-client cli-rtr cli-c1 cli-c2
bridge br-backend be-bfw be-loki be-graf be-alloy

echo; echo "Ergebnis: $pass PASS, $fail FAIL"
[ "$fail" -eq 0 ]
