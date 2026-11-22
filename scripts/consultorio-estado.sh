#!/bin/bash
# Registra el estado del servidor del Centro de Terapias Bienestar cada 60 segundos
LOG=/var/log/consultorio/estado.log
mkdir -p /var/log/consultorio
while true; do
  HOY=$(date +%F)
  ARCHIVO=/srv/consultorio/citas/citas_$HOY.csv
  if [ -f "$ARCHIVO" ]; then
    CITAS=$(( $(wc -l < "$ARCHIVO") - 1 ))
  else
    CITAS=0
  fi
  DISCO=$(df -h /srv | awk 'NR==2{print $5}')
  echo "$(date '+%F %T') | encendido: $(uptime -p) | disco usado: $DISCO | citas hoy: $CITAS" >> "$LOG"
  sleep 60
done
