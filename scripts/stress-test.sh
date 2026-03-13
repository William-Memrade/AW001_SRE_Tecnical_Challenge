#!/bin/bash

# Script de estrés para Nginx
# Uso: ./stress-test.sh <URL> <RPS> <DURACION_SEGUNDOS>

URL=$1
RPS=$2
DURATION=$3

if [ -z "$URL" ] || [ -z "$RPS" ] || [ -z "$DURATION" ]; then
    echo "Uso: $0 <URL> <RPS> <DURACION_SEGUNDOS>"
    exit 1
fi

echo "🚀 Iniciando prueba de estrés..."
echo "📍 Objetivo: $URL"
echo "📊 Tasa: $RPS peticiones/segundo"
echo "⏱️ Duración: $DURATION segundos"

START_TIME=$(date +%s)
END_TIME=$((START_TIME + DURATION))

send_request() {
    curl -s -o /dev/null -w "%{http_code}" "$URL"
}

export -f send_request
export URL

while [ $(date +%s) -lt $END_TIME ]; do
    for ((i=1; i<=RPS; i++)); do
        send_request &
    done
    sleep 1
done

wait
echo -e "\n✅ Prueba de estrés finalizada."
