# Suricata fuer IDS (passiv) und IPS 1/2 (inline per NFQUEUE).
# Dasselbe Image, unterschiedliche Startmodi (siehe configs/ids und configs/ips).
FROM alpine:3.22

RUN apk add --no-cache \
      suricata \
      iproute2 \
      nftables \
      tcpdump \
      jq

# Regeln und Konfiguration werden per Bind-Mount bzw. docker cp eingespielt.
CMD ["tail", "-f", "/dev/null"]
