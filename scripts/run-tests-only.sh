#!/usr/bin/env bash
set -euo pipefail

# Script para executar apenas os testes do k8s-addon
# Uso: ./run-tests-only.sh
# Pré-requisito: k8s-addon já deve estar deployado no cluster

echo "🧪 Executando testes do k8s-addon..."
echo "💡 Assumindo que o addon já está deployado no cluster"
echo "=====================================\n"

# Verificar se addon está rodando
ADDON_POD_STATUS=$(kubectl -n kube-system get pods -l app=k8s-addon --no-headers 2>/dev/null || echo "")
if [[ -z "$ADDON_POD_STATUS" ]] || ! echo "$ADDON_POD_STATUS" | grep -q "Running"; then
    echo "❌ k8s-addon não está rodando no cluster"
    echo "📋 Status atual:"
    kubectl -n kube-system get pods -l app=k8s-addon 2>/dev/null || echo "Nenhum pod encontrado"
    echo "💡 Execute ./run-all.sh ou ./deploy-addon.sh primeiro"
    exit 1
fi

echo "✅ k8s-addon está rodando, iniciando testes...\n"

# Teste 1: NamespaceController
echo "TESTE 1: NamespaceController"
echo "----------------------------"
./test-namespace.sh
echo ""

# Teste 2: NodeController
echo "TESTE 2: NodeController"
echo "-----------------------"
./test-node.sh
echo ""

echo "=====================================\n"
echo "✅ Todos os testes executados com sucesso!"
echo ""
echo "📋 Comandos de monitoramento:"
echo "  - Ver logs: kubectl -n kube-system logs -l app=k8s-addon -f"
echo "  - Health check: kubectl -n kube-system port-forward deploy/k8s-addon 8081:8081"
echo "  - Métricas: kubectl -n kube-system port-forward deploy/k8s-addon 8080:8080" 