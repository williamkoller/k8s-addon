#!/usr/bin/env bash
set -euo pipefail

# Script para testar o NamespaceController
# Uso: ./test-namespace.sh [NAMESPACE_NAME]

NAMESPACE_NAME="${1:-teste-addon}"
EXPECTED_LABEL_KEY="owner"
EXPECTED_LABEL_VALUE="platform"

echo "📦 Testando NamespaceController..."
echo "🎯 Namespace de teste: $NAMESPACE_NAME"

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

# Deletar namespace se já existir
if kubectl get namespace "$NAMESPACE_NAME" >/dev/null 2>&1; then
    echo "🗑️ Deletando namespace existente..."
    kubectl delete namespace "$NAMESPACE_NAME"
    sleep 2
fi

# Criar namespace de teste
echo "➕ Criando namespace de teste: $NAMESPACE_NAME"
kubectl create namespace "$NAMESPACE_NAME"

# Aguardar um pouco para o controlador processar
echo "⏳ Aguardando controlador processar (5 segundos)..."
sleep 5

# Verificar se label foi adicionado
echo "🔍 Verificando se label foi adicionado..."
ACTUAL_LABEL=$(kubectl get namespace "$NAMESPACE_NAME" -o jsonpath="{.metadata.labels.$EXPECTED_LABEL_KEY}" 2>/dev/null || echo "")

if [[ "$ACTUAL_LABEL" == "$EXPECTED_LABEL_VALUE" ]]; then
    echo "✅ Teste PASSOU! Label '$EXPECTED_LABEL_KEY: $EXPECTED_LABEL_VALUE' encontrado"
    echo "📋 Labels do namespace:"
    kubectl get namespace "$NAMESPACE_NAME" -o jsonpath='{.metadata.labels}' | jq .
else
    echo "❌ Teste FALHOU!"
    echo "🎯 Esperado: $EXPECTED_LABEL_KEY=$EXPECTED_LABEL_VALUE"
    echo "📋 Encontrado: $EXPECTED_LABEL_KEY=$ACTUAL_LABEL"
    echo "📋 Todos os labels do namespace:"
    kubectl get namespace "$NAMESPACE_NAME" -o jsonpath='{.metadata.labels}' | jq .
    
    echo "🔍 Verificando logs do addon para debug..."
    kubectl -n kube-system logs -l app=k8s-addon --tail=10
    exit 1
fi

# Limpeza (opcional - comentado para permitir inspeção manual)
# echo "🗑️ Removendo namespace de teste..."
# kubectl delete namespace "$NAMESPACE_NAME"

echo "✅ Teste do NamespaceController concluído com sucesso!" 