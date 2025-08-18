#!/usr/bin/env bash
set -euo pipefail

# Script para remover o k8s-addon do cluster
# Uso: ./cleanup.sh

NAMESPACE="kube-system"
APP_NAME="k8s-addon"

echo "🗑️ Removendo k8s-addon do cluster..."

# Verificar conectividade com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes"
    exit 1
fi

# Remover deployment
echo "📦 Removendo deployment..."
if kubectl -n "$NAMESPACE" get deploy "$APP_NAME" >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" delete deploy "$APP_NAME"
    echo "✅ Deployment removido"
else
    echo "ℹ️ Deployment não encontrado"
fi

# Remover RBAC
echo "🔑 Removendo permissões RBAC..."
if [[ -f "manifests/rbac.yaml" ]]; then
    kubectl delete -f manifests/rbac.yaml --ignore-not-found=true
    echo "✅ RBAC removido"
else
    echo "⚠️ Arquivo RBAC não encontrado, tentando remoção manual..."
    kubectl delete clusterrole "$APP_NAME" --ignore-not-found=true
    kubectl delete clusterrolebinding "$APP_NAME" --ignore-not-found=true
    kubectl -n "$NAMESPACE" delete serviceaccount "$APP_NAME" --ignore-not-found=true
fi

# Remover namespace de teste se existir
TEST_NAMESPACE="teste-addon"
if kubectl get namespace "$TEST_NAMESPACE" >/dev/null 2>&1; then
    echo "🧪 Removendo namespace de teste..."
    kubectl delete namespace "$TEST_NAMESPACE"
    echo "✅ Namespace de teste removido"
fi

# Verificar se tudo foi removido
echo "🔍 Verificando remoção..."
if kubectl -n "$NAMESPACE" get pods -l "app=$APP_NAME" 2>/dev/null | grep -q "$APP_NAME"; then
    echo "⚠️ Ainda existem pods do $APP_NAME rodando"
    kubectl -n "$NAMESPACE" get pods -l "app=$APP_NAME"
else
    echo "✅ Todos os pods removidos"
fi

if kubectl get clusterrole "$APP_NAME" >/dev/null 2>&1; then
    echo "⚠️ ClusterRole ainda existe"
else
    echo "✅ ClusterRole removido"
fi

echo "✅ Limpeza concluída!"
echo "💡 Para limpar imagens Docker locais, execute: docker rmi k8s-addon:dev" 