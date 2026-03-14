#!/bin/bash

# Script de estrés para Nginx (versión segura)
# Uso: ./stress-test.sh <URL> <RPS> <DURACION_SEGUNDOS>
# Implementación: genera RPS * DURATION peticiones y las ejecuta con hasta RPS procesos concurrentes usando xargs.

set -euo pipefail

URL=${1:-}
RPS=${2:-}
DURATION=${3:-}

if [ -z "$URL" ] || [ -z "$RPS" ] || [ -z "$DURATION" ]; then
    echo "Uso: $0 <URL> <RPS> <DURACION_SEGUNDOS>"
    exit 1
fi

echo "🚀 Iniciando prueba de estrés..."
echo "📍 Objetivo: $URL"
echo "📊 Tasa objetivo: $RPS peticiones/segundo"
echo "⏱️ Duración: $DURATION segundos"

# Número total de peticiones
N=$(( RPS * DURATION ))

echo "🔁 Total peticiones: $N"

# Comprobación rápida de disponibilidad de xargs
if ! command -v xargs >/dev/null 2>&1; then
    echo "xargs no encontrado. Instala utilidades GNU xargs o usa vegeta (recomendado)."
    exit 1
fi

# Ejecutar peticiones con concurrencia controlada
# -n1 : pasar un número por invocación (ignorado por curl)
# -P ${RPS} : concurrencia máxima
seq $N | xargs -n1 -P "$RPS" -I{} curl -s -o /dev/null -w "%{http_code}\n" "$URL" || true

echo "✅ Prueba de estrés finalizada."

echo "Sugerencia: para pruebas más fiables y controladas instala 'vegeta' o 'wrk'. Ejemplo con vegeta:" 
echo "  echo \"GET $URL\" | vegeta attack -rate=${RPS}/s -duration=${DURATION}s | vegeta report"
