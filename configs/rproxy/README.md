# Reverse-Proxy + WAF (rproxy, F-DMZ)

Image: `owasp/modsecurity-crs:nginx` mit OWASP Core Rule Set.

## Wirkung (SF-05/06/07)
- **TLS-Terminierung** auf 443, Weiterleitung an den Webserver per HTTP (`BACKEND=http://10.0.10.18:80`, F05).
- **HTTP → HTTPS**: Port 80 antwortet mit 301 (im Image via Serverkonfiguration; siehe `MODSEC`-Doku).
- **WAF im Blockiermodus** (`MODSEC_RULE_ENGINE=On`): SQLi, XSS, Path Traversal werden mit 403 beantwortet und im Audit-Log festgehalten.
- **Paranoia-Level** über `PARANOIA` steuerbar (1 = wenige Fehlalarme, 4 = sehr streng). Für die verschleierten Angriffe aus Kette B lohnt ein Test mit Level 2.

## Zertifikat
Das Image erzeugt beim Start ein selbstsigniertes Zertifikat. Für die Demo genügt das. Ein eigenes Zertifikat kann über `SSL_CERT` / `SSL_CERT_KEY` eingebunden werden.

## Logs für das SIEM (SF-11)
Audit- und Access-Log nach `/var/log/sun/rproxy/` schreiben lassen (Bind-Mount, siehe `docs/INSTALL.md`). Alloy liest dieses Verzeichnis auf der VM.

## Funktionstest
`tests/03_waf.sh` sendet eine harmlose SQLi-Probe gegen die eigene WAF und erwartet HTTP 403.
