# Image fuer Endgeraete und Testquellen: ang-internet, Clients, ro-client1.
# Enthaelt bewusst Standard-Testwerkzeuge, weil von hier die Funktions- und Angriffstests ausgehen.
FROM alpine:3.22

RUN apk add --no-cache \
      iproute2 \
      curl \
      openssl \
      nmap \
      nmap-scripts \
      bind-tools \
      netcat-openbsd \
      wireguard-tools-wg \
      tcpdump

CMD ["tail", "-f", "/dev/null"]
