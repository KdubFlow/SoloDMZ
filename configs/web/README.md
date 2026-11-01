# Webserver (web, B1-DMZ)

Der Webserver wird aus dem Image `images/sun-web` gebaut (statische nginx-Seite,
ADR Ä19). Es gibt hier bewusst keine Anwendung: WAF (SF-05) und IPS 1 (SF-08)
prüfen die **Anfrage**, nicht die Seite dahinter.

- Inhalt der Seite: `images/sun-web/index.html`
- Erreichbar nur über den Reverse-Proxy (F05), nie direkt (Test T11).
- Access-Log nach `/var/log/sun/web/` leiten (Bind-Mount, siehe INSTALL §3).

Für Kette A (Dateifreigabe auf `client2`) genügt ein zweiter kleiner HTTP-Dienst
auf `client2:8080` mit fiktiven Beispieldaten – das ist kein Teil dieses Webservers.
