#!/bin/bash

# Script de prueba de carga controlada para endpoints HTTP
# Uso:
# ./stress-test.sh <URL> <RPS> <DURACION>

set -euo pipefail

URL=${1:-}
RPS=${2:-}
DURATION=${3:-}

if [[ -z "$URL" || -z "$RPS" || -z "$DURATION" ]]; then
    echo "Uso: $0 <URL> <RPS> <DURACION_SEGUNDOS>"
    exit 1
fi

echo "--------------------------------------------------"
echo "🚀 Iniciando prueba de carga"
echo "📍 URL: $URL"
echo "📊 RPS objetivo: $RPS"
echo "⏱ Duración: $DURATION segundos"
echo "--------------------------------------------------"

TOTAL=$((RPS * DURATION))
CONCURRENCY=$((RPS / 2))

if [[ "$CONCURRENCY" -lt 1 ]]; then
  CONCURRENCY=1
fi

echo "🔁 Total de requests: $TOTAL"
echo "⚙️ Concurrencia: $CONCURRENCY"
echo ""

SUCCESS=0
FAIL=0

run_request() {
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "$URL" || echo "000")

    if [[ "$CODE" == "200" ]]; then
        echo "200"
    else
        echo "$CODE"
    fi
}

export URL
export -f run_request

RESULTS=$(seq "$TOTAL" | xargs -n1 -P "$CONCURRENCY" -I{} bash -c 'run_request')

SUCCESS=$(echo "$RESULTS" | grep -c '^200$' || true)
FAIL=$((TOTAL - SUCCESS))

echo ""
echo "---------------- RESULTADOS ----------------"
echo "Total Requests : $TOTAL"
echo "Success (200)  : $SUCCESS"
echo "Fail           : $FAIL"

SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS/$TOTAL)*100}")

echo "Success Rate   : $SUCCESS_RATE %"
echo "--------------------------------------------"
echo "✅ Prueba finalizada"
echo ""
