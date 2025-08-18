#!/usr/bin/env bash
set -euo pipefail

# Script para deploy do k8s-addon no cluster
# Uso: ./deploy-addon.sh [IMAGE_NAME]

IMAGE_NAME="${1:-k8s-addon:dev}"
DEPLOYMENT_FILE="manifests/deployment.yaml"
NAMESPACE="kube-system"

echo "🚀 Deployando k8s-addon no cluster..."
echo "📦 Imagem: $IMAGE_NAME"

# Verificar se arquivo de deployment existe
if [[ ! -f "$DEPLOYMENT_FILE" ]]; then
    echo "❌ Arquivo de deployment não encontrado: $DEPLOYMENT_FILE"
    exit 1
fi

# Verificar conectividade com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Não foi possível conectar ao cluster Kubernetes"
    exit 1
fi

# Fazer backup do deployment original
cp "$DEPLOYMENT_FILE" "${DEPLOYMENT_FILE}.bak"

# Atualizar imagem no deployment
echo "🔧 Atualizando imagem no deployment para: $IMAGE_NAME"
sed -E -i "s|image: .*|image: $IMAGE_NAME|" "$DEPLOYMENT_FILE"

# Aplicar deployment
echo "📋 Aplicando deployment..."
kubectl apply -f "$DEPLOYMENT_FILE"

# Restaurar arquivo original
mv "${DEPLOYMENT_FILE}.bak" "$DEPLOYMENT_FILE"

# Reiniciar deployment para garantir que nova imagem seja usada
echo "🔄 Reiniciando deployment..."
kubectl -n "$NAMESPACE" rollout restart deploy/k8s-addon

# Aguardar deployment ficar pronto
echo "⏳ Aguardando deployment ficar pronto..."
if ! kubectl -n "$NAMESPACE" rollout status deploy/k8s-addon --timeout=60s; then
    echo "⚠️ Timeout no rollout, verificando problemas de agendamento..."
    
    # Verificar se há pods pending por causa de taints
    PENDING_PODS=$(kubectl -n "$NAMESPACE" get pods -l app=k8s-addon --field-selector=status.phase=Pending --no-headers 2>/dev/null || echo "")
    
    if [[ -n "$PENDING_PODS" ]]; then
        echo "🔍 Pods em estado Pending detectados, verificando eventos..."
        POD_NAME=$(echo "$PENDING_PODS" | head -1 | awk '{print $1}')
        EVENTS=$(kubectl -n "$NAMESPACE" describe pod "$POD_NAME" | grep -A 3 "Events:" || echo "")
        
        if echo "$EVENTS" | grep -q "untolerated taint"; then
            echo "🔧 Problema de taint detectado, aplicando correção..."
            kubectl apply -f "$DEPLOYMENT_FILE"
            kubectl -n "$NAMESPACE" rollout status deploy/k8s-addon --timeout=60s
        else
            echo "❌ Problema desconhecido de agendamento"
            echo "$EVENTS"
            exit 1
        fi
    else
        echo "❌ Timeout sem pods pending - problema desconhecido"
        exit 1
    fi
fi

# Verificar se deployment está pronto
echo "🔍 Verificando status dos pods..."
POD_STATUS=$(kubectl -n "$NAMESPACE" get pods -l app=k8s-addon --no-headers 2>/dev/null || echo "")

if [[ -n "$POD_STATUS" ]] && echo "$POD_STATUS" | grep -q "Running"; then
    echo "✅ Deployment realizado com sucesso!"
    kubectl -n "$NAMESPACE" get pods -l app=k8s-addon
elif [[ -n "$POD_STATUS" ]] && echo "$POD_STATUS" | grep -q "ImagePullBackOff"; then
    echo "⚠️ Erro de ImagePullBackOff detectado - tentando resolver..."
    echo "🔧 Configurando Docker para Minikube e fazendo rebuild..."
    
    # Configurar Docker para Minikube
    eval $(minikube docker-env)
    
    # Rebuild da imagem
    echo "📦 Fazendo rebuild da imagem no contexto Minikube..."
    docker build -t "$IMAGE_NAME" .
    
    # Restart do deployment
    echo "🔄 Reiniciando deployment..."
    kubectl -n "$NAMESPACE" rollout restart deploy/k8s-addon
    kubectl -n "$NAMESPACE" rollout status deploy/k8s-addon --timeout=120s
    
    echo "✅ Problema resolvido! Deployment pronto."
    kubectl -n "$NAMESPACE" get pods -l app=k8s-addon
else
    echo "❌ Erro: Pods não estão rodando corretamente"
    echo "📋 Status atual dos pods:"
    kubectl -n "$NAMESPACE" get pods -l app=k8s-addon
    echo ""
    echo "🔍 Logs para debug:"
    kubectl -n "$NAMESPACE" logs -l app=k8s-addon --tail=10
    exit 1
fi 