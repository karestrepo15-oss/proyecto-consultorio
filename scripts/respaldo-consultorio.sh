#!/bin/bash
# Respaldo del Centro de Terapias Bienestar
umask 077
DESTINO=/backups/consultorio_$(date +%F_%H%M).tar.gz
tar -czpf "$DESTINO" -C /srv consultorio
echo "$(date '+%F %T') respaldo creado: $DESTINO" >> /var/log/consultorio/respaldo.log
find /backups -name 'consultorio_*.tar.gz' -mtime +7 -delete
