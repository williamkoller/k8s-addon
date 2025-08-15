#!/usr/bin/env bash
set -euo pipefail

# Script para aguardar os controladores estarem prontos
# Uso: ./wait-for-controllers.sh [TIMEOUT_SECONDS]

TIMEOUT_SECONDS="${1:-60}"
NAMESPACE="kube-system"
APP_NAME="k8s-addon"

echo "⏳ Aguardando controladores ficarem prontos (timeout: ${TIMEOUT_SECONDS}s)..."

# Verificar se o pod está rodando
if ! kubectl -n "$NAMESPACE" get pods -l app="$APP_NAME" | grep -q "Running"; then
    echo "❌ Pod do addon não está rodando"
    exit 1
fi

echo "✅ Pod está rodando, aguardando leader election e inicialização dos controladores..."

START_TIME=$(date +%s)
CONTROLLERS_READY=false

while [[ $CONTROLLERS_READY == false ]]; do
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [[ $ELAPSED_TIME -gt $TIMEOUT_SECONDS ]]; then
        echo "❌ Timeout aguardando controladores ficarem prontos"
        echo "🔍 Logs atuais:"
        kubectl -n "$NAMESPACE" logs -l app="$APP_NAME" --tail=10
        exit 1
    fi
    
    # Verificar se leader election foi concluída e controladores iniciaram
    LOGS=$(kubectl -n "$NAMESPACE" logs -l app="$APP_NAME" --tail=20 2>/dev/null || echo "")
    
    if echo "$LOGS" | grep -q "successfully acquired lease" && \
       echo "$LOGS" | grep -q "Starting workers.*namespace" && \
       echo "$LOGS" | grep -q "Starting workers.*node"; then
        CONTROLLERS_READY=true
        echo "✅ Controladores prontos! (${ELAPSED_TIME}s)"
        break
    fi
    
    echo "⏳ Aguardando... (${ELAPSED_TIME}s/${TIMEOUT_SECONDS}s)"
    sleep 3
done

echo "🎯 Controladores estão ativos e prontos para processar eventos!" 