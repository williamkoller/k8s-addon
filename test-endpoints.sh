#!/usr/bin/env bash
set -euo pipefail

# Script para testar rapidamente os endpoints do k8s-addon
# Uso: ./test-endpoints.sh

NAMESPACE="kube-system"
APP_NAME="k8s-addon"

echo "🔍 Testando endpoints do k8s-addon..."

# Verificar se addon está rodando
if ! kubectl -n "$NAMESPACE" get pods -l app="$APP_NAME" | grep -q "Running"; then
    echo "❌ k8s-addon não está rodando. Execute deploy primeiro."
    exit 1
fi

# Fazer port-forwards em background
echo "📋 Iniciando port-forwards temporários..."
kubectl -n "$NAMESPACE" port-forward deploy/"$APP_NAME" 8081:8081 &
PF1_PID=$!
kubectl -n "$NAMESPACE" port-forward deploy/"$APP_NAME" 8080:8080 &
PF2_PID=$!

# Função de cleanup
cleanup() {
    echo ""
    echo "🧹 Parando port-forwards..."
    kill $PF1_PID $PF2_PID 2>/dev/null || true
}

# Capturar sinais para cleanup
trap cleanup EXIT

# Aguardar port-forwards ficarem prontos
echo "⏳ Aguardando port-forwards (5s)..."
sleep 5

echo ""
echo "🏥 HEALTH CHECKS"
echo "=================="

# Teste Liveness
echo "🔍 Testando /healthz..."
if HEALTH_RESPONSE=$(curl -s http://localhost:8081/healthz 2>/dev/null); then
    echo "✅ Liveness: $HEALTH_RESPONSE"
else
    echo "❌ Liveness: Falhou"
fi

# Teste Readiness  
echo "🔍 Testando /readyz..."
if READY_RESPONSE=$(curl -s http://localhost:8081/readyz 2>/dev/null); then
    echo "✅ Readiness: $READY_RESPONSE"
else
    echo "❌ Readiness: Falhou"
fi

echo ""
echo "📊 MÉTRICAS PROMETHEUS"
echo "======================"

# Teste Métricas
echo "🔍 Testando /metrics..."
if METRICS_RESPONSE=$(curl -s http://localhost:8080/metrics 2>/dev/null); then
    # Contar métricas
    METRIC_COUNT=$(echo "$METRICS_RESPONSE" | grep -c "^# TYPE" || echo "0")
    echo "✅ Métricas: $METRIC_COUNT tipos encontrados"
    
    echo ""
    echo "📈 Métricas principais do controlador:"
    echo "$METRICS_RESPONSE" | grep "controller_runtime_reconcile" | head -3
    
    echo ""
    echo "🎯 Métricas de leader election:"
    echo "$METRICS_RESPONSE" | grep "leader_election" | head -2
    
else
    echo "❌ Métricas: Falhou"
fi

echo ""
echo "🌐 URLs para browser:"
echo "  - Health: http://localhost:8081/healthz"
echo "  - Ready: http://localhost:8081/readyz" 
echo "  - Metrics: http://localhost:8080/metrics"

echo ""
echo "💡 Para manter port-forwards ativos use: ./web-test.sh" 