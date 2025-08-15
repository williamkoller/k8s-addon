#!/usr/bin/env bash
set -euo pipefail

# Script para aplicar permissões RBAC do k8s-addon
# Uso: ./deploy-rbac.sh

RBAC_FILE="manifests/rbac.yaml"

echo "🔑 Aplicando permissões RBAC..."

# Verificar se arquivo RBAC existe
if [[ ! -f "$RBAC_FILE" ]]; then
    echo "❌ Arquivo RBAC não encontrado: $RBAC_FILE"
    exit 1
fi

# Verificar se kubectl está disponível
if ! command -v kubectl >/dev/null 2>&1; then
    echo "❌ kubectl não encontrado. Instale kubectl primeiro."
    exit 1
fi

# Verificar conectividade com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes"
    echo "💡 Verifique se kubectl está configurado corretamente"
    exit 1
fi

# Aplicar RBAC
echo "📋 Aplicando $RBAC_FILE..."
kubectl apply -f "$RBAC_FILE"

# Verificar se ServiceAccount foi criado
echo "🔍 Verificando criação do ServiceAccount..."
if kubectl -n kube-system get serviceaccount k8s-addon >/dev/null 2>&1; then
    echo "✅ ServiceAccount 'k8s-addon' criado com sucesso"
else
    echo "❌ Erro: ServiceAccount não foi criado"
    exit 1
fi

# Verificar se ClusterRole foi criado
if kubectl get clusterrole k8s-addon >/dev/null 2>&1; then
    echo "✅ ClusterRole 'k8s-addon' criado com sucesso"
else
    echo "❌ Erro: ClusterRole não foi criado"
    exit 1
fi

echo "✅ Permissões RBAC aplicadas com sucesso!" 