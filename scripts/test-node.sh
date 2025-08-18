#!/usr/bin/env bash
set -euo pipefail

# Script para testar o NodeController
# Uso: ./test-node.sh [NODE_NAME]

NODE_NAME="${1:-}"
GPU_LABEL_KEY="gpu"
GPU_LABEL_VALUE="true"
EXPECTED_TAINT_KEY="nvidia.com/gpu"
EXPECTED_TAINT_VALUE="true"
EXPECTED_TAINT_EFFECT="NoSchedule"

echo "💻 Testando NodeController..."

# Verificar conectividade com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes"
    exit 1
fi

# Verificar se addon está rodando
ADDON_POD_STATUS=$(kubectl -n kube-system get pods -l app=k8s-addon --no-headers 2>/dev/null || echo "")
if [[ -z "$ADDON_POD_STATUS" ]] || ! echo "$ADDON_POD_STATUS" | grep -q "Running"; then
    echo "❌ k8s-addon não está rodando. Execute deploy-addon.sh primeiro."
    echo "📋 Status atual:"
    kubectl -n kube-system get pods -l app=k8s-addon 2>/dev/null || echo "Nenhum pod encontrado"
    exit 1
fi

# Se node não foi especificado, usar o primeiro disponível
if [[ -z "$NODE_NAME" ]]; then
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    echo "🎯 Nenhum node especificado, usando: $NODE_NAME"
else
    echo "🎯 Node de teste: $NODE_NAME"
fi

# Verificar se node existe
if ! kubectl get node "$NODE_NAME" >/dev/null 2>&1; then
    echo "❌ Node '$NODE_NAME' não encontrado"
    echo "📋 Nodes disponíveis:"
    kubectl get nodes -o name
    exit 1
fi

# Remover label GPU se já existir (para garantir teste limpo)
echo "🧹 Removendo label GPU existente (se houver)..."
kubectl label node "$NODE_NAME" "$GPU_LABEL_KEY-" 2>/dev/null || true

# Remover taint GPU se já existir
echo "🧹 Removendo taint GPU existente (se houver)..."
kubectl taint node "$NODE_NAME" "$EXPECTED_TAINT_KEY-" 2>/dev/null || true

# Aguardar um pouco
sleep 2

# Aplicar label GPU
echo "🏷️ Aplicando label GPU ao node: $GPU_LABEL_KEY=$GPU_LABEL_VALUE"
kubectl label node "$NODE_NAME" "$GPU_LABEL_KEY=$GPU_LABEL_VALUE" --overwrite

# Aguardar controlador processar
echo "⏳ Aguardando controlador processar (5 segundos)..."
sleep 5

# Verificar se taint foi aplicado
echo "🔍 Verificando se taint foi aplicado..."
TAINTS=$(kubectl get node "$NODE_NAME" -o jsonpath='{.spec.taints}')

# Usar jq para verificar se o taint correto existe
if echo "$TAINTS" | jq -e ".[] | select(.key==\"$EXPECTED_TAINT_KEY\" and .value==\"$EXPECTED_TAINT_VALUE\" and .effect==\"$EXPECTED_TAINT_EFFECT\")" >/dev/null 2>&1; then
    echo "✅ Teste PASSOU! Taint '$EXPECTED_TAINT_KEY=$EXPECTED_TAINT_VALUE:$EXPECTED_TAINT_EFFECT' encontrado"
    echo "📋 Taints do node:"
    echo "$TAINTS" | jq .
else
    echo "❌ Teste FALHOU!"
    echo "🎯 Esperado: $EXPECTED_TAINT_KEY=$EXPECTED_TAINT_VALUE:$EXPECTED_TAINT_EFFECT"
    echo "📋 Taints encontrados:"
    echo "$TAINTS" | jq .
    
    echo "🔍 Verificando logs do addon para debug..."
    kubectl -n kube-system logs -l app=k8s-addon --tail=10
    exit 1
fi

# Limpeza (opcional - comentado para permitir inspeção manual)
# echo "🧹 Removendo label e taint de teste..."
# kubectl label node "$NODE_NAME" "$GPU_LABEL_KEY-"
# kubectl taint node "$NODE_NAME" "$EXPECTED_TAINT_KEY-"

echo "✅ Teste do NodeController concluído com sucesso!" 