# Basis-Image fuer Router, Firewalls und VPN-Gateways.
# Nur Netzwerk-Werkzeuge, keine Angriffs- oder Komfort-Tools (minimale Angriffsflaeche, SF-12).
FROM alpine:3.22

RUN apk add --no-cache \
      iproute2 \
      nftables \
      conntrack-tools \
      wireguard-tools-wg \
      tcpdump

# Container laeuft dauerhaft; die Konfiguration erfolgt von aussen (configure-net.sh + configs/).
CMD ["tail", "-f", "/dev/null"]
