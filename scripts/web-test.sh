#!/usr/bin/env bash
set -euo pipefail

# Script para testar k8s-addon via web (health checks e métricas)
# Uso: ./web-test.sh [health|metrics|both]

MODE="${1:-both}"
NAMESPACE="kube-system"
APP_NAME="k8s-addon"

echo "🌐 Testando k8s-addon via web..."

# Verificar se addon está rodando
if ! kubectl -n "$NAMESPACE" get pods -l app="$APP_NAME" | grep -q "Running"; then
    echo "❌ k8s-addon não está rodando. Execute deploy primeiro."
    exit 1
fi

case "$MODE" in
    "health")
        echo "🏥 Iniciando health checks web..."
        echo "📋 Fazendo port-forward para porta 8081..."
        kubectl -n "$NAMESPACE" port-forward deploy/"$APP_NAME" 8081:8081 &
        PF_PID=$!
        
        # Aguardar port-forward estar pronto
        sleep 3
        
        echo "🔍 Testando endpoints de health..."
        echo "📍 Liveness: http://localhost:8081/healthz"
        echo "📍 Readiness: http://localhost:8081/readyz"
        
        # Testes automáticos
        echo ""
        echo "🧪 Testando automaticamente..."
        
        if curl -s http://localhost:8081/healthz | grep -q "ok"; then
            echo "✅ Liveness check: OK"
        else
            echo "❌ Liveness check: FALHOU"
        fi
        
        if curl -s http://localhost:8081/readyz | grep -q "ok"; then
            echo "✅ Readiness check: OK"
        else
            echo "❌ Readiness check: FALHOU"
        fi
        
        echo ""
        echo "🌐 Abra no browser:"
        echo "  - http://localhost:8081/healthz"
        echo "  - http://localhost:8081/readyz"
        echo ""
        echo "⏹️  Pressione Ctrl+C para parar o port-forward"
        
        # Manter port-forward ativo
        wait $PF_PID
        ;;
        
    "metrics")
        echo "📊 Iniciando métricas web..."
        echo "📋 Fazendo port-forward para porta 8080..."
        kubectl -n "$NAMESPACE" port-forward deploy/"$APP_NAME" 8080:8080 &
        PF_PID=$!
        
        # Aguardar port-forward estar pronto
        sleep 3
        
        echo "📈 Testando endpoint de métricas..."
        echo "📍 Métricas: http://localhost:8080/metrics"
        
        # Teste automático
        echo ""
        echo "🧪 Testando automaticamente..."
        
        METRICS=$(curl -s http://localhost:8080/metrics)
        if echo "$METRICS" | grep -q "controller_runtime"; then
            echo "✅ Métricas Prometheus: OK"
            echo "📊 Métricas encontradas:"
            echo "$METRICS" | grep "controller_runtime" | head -5
        else
            echo "❌ Métricas Prometheus: FALHOU"
        fi
        
        echo ""
        echo "🌐 Abra no browser:"
        echo "  - http://localhost:8080/metrics"
        echo ""
        echo "⏹️  Pressione Ctrl+C para parar o port-forward"
        
        # Manter port-forward ativo
        wait $PF_PID
        ;;
        
    "both")
        echo "🔄 Testando health checks e métricas..."
        
        # Fazer ambos os port-forwards
        echo "📋 Fazendo port-forward para health (8081) e métricas (8080)..."
        kubectl -n "$NAMESPACE" port-forward deploy/"$APP_NAME" 8081:8081 &
        PF1_PID=$!
        kubectl -n "$NAMESPACE" port-forward deploy/"$APP_NAME" 8080:8080 &
        PF2_PID=$!
        
        # Aguardar port-forwards estarem prontos
        sleep 5
        
        echo "🧪 Testando todos os endpoints..."
        
        # Health checks
        if curl -s http://localhost:8081/healthz | grep -q "ok"; then
            echo "✅ Liveness check: OK"
        else
            echo "❌ Liveness check: FALHOU"
        fi
        
        if curl -s http://localhost:8081/readyz | grep -q "ok"; then
            echo "✅ Readiness check: OK"
        else
            echo "❌ Readiness check: FALHOU"
        fi
        
        # Métricas
        if curl -s http://localhost:8080/metrics | grep -q "controller_runtime"; then
            echo "✅ Métricas Prometheus: OK"
        else
            echo "❌ Métricas Prometheus: FALHOU"
        fi
        
        echo ""
        echo "🌐 Abra no browser:"
        echo "  - Health Liveness: http://localhost:8081/healthz"
        echo "  - Health Readiness: http://localhost:8081/readyz"
        echo "  - Métricas Prometheus: http://localhost:8080/metrics"
        echo ""
        echo "⏹️  Pressione Ctrl+C para parar os port-forwards"
        
        # Função para cleanup
        cleanup() {
            echo ""
            echo "🧹 Parando port-forwards..."
            kill $PF1_PID $PF2_PID 2>/dev/null || true
            exit 0
        }
        
        # Capturar Ctrl+C
        trap cleanup SIGINT
        
        # Manter port-forwards ativos
        wait
        ;;
        
    *)
        echo "❌ Modo inválido: $MODE"
        echo "💡 Use: health, metrics, ou both"
        exit 1
        ;;
esac 