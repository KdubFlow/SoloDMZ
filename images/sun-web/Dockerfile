# Webserver (B1-DMZ): statische Seite (ADR Ä19).
# Die WAF und IPS 1 pruefen die ANFRAGE; die Seite selbst muss nicht verwundbar sein.
FROM nginx:1.27-alpine

COPY index.html /usr/share/nginx/html/index.html
# Webserver lauscht nur auf 80; TLS wird am Reverse-Proxy terminiert (SF-06).
EXPOSE 80
