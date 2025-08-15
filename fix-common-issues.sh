#!/usr/bin/env bash
set -euo pipefail

# Script para diagnosticar e corrigir problemas comuns do k8s-addon
# Uso: ./fix-common-issues.sh

echo "🔍 Diagnosticando problemas comuns do k8s-addon..."

# 1. Verificar se Minikube está rodando
if ! minikube status >/dev/null 2>&1; then
    echo "❌ Minikube não está rodando"
    echo "🔧 Tentando iniciar Minikube..."
    minikube start --driver=docker --kubernetes-version=v1.31.3
    echo "✅ Minikube iniciado"
else
    echo "✅ Minikube está rodando"
fi

# 2. Verificar conectividade com cluster
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Não é possível conectar ao cluster Kubernetes"
    echo "🔧 Tentando reconfigurar kubectl..."
    minikube update-context
    echo "✅ Kubectl reconfigurado"
else
    echo "✅ Conectividade com cluster OK"
fi

# 3. Verificar se RBAC está aplicado
if ! kubectl -n kube-system get serviceaccount k8s-addon >/dev/null 2>&1; then
    echo "❌ RBAC não está configurado"
    echo "🔧 Aplicando RBAC..."
    ./deploy-rbac.sh
    echo "✅ RBAC configurado"
else
    echo "✅ RBAC está configurado"
fi

# 4. Verificar imagem Docker no contexto Minikube
echo "🔍 Verificando imagem Docker..."
eval $(minikube docker-env)

if ! docker images k8s-addon:dev --format "table {{.Repository}}:{{.Tag}}" | grep -q "k8s-addon:dev"; then
    echo "❌ Imagem k8s-addon:dev não encontrada no contexto Minikube"
    echo "🔧 Fazendo build da imagem..."
    ./build-image.sh k8s-addon:dev
    echo "✅ Imagem criada"
else
    echo "✅ Imagem k8s-addon:dev encontrada"
fi

# 5. Verificar status do deployment
DEPLOYMENT_EXISTS=$(kubectl -n kube-system get deployment k8s-addon --no-headers 2>/dev/null || echo "")

if [[ -z "$DEPLOYMENT_EXISTS" ]]; then
    echo "❌ Deployment não existe"
    echo "🔧 Criando deployment..."
    ./deploy-addon.sh k8s-addon:dev
    echo "✅ Deployment criado"
else
    echo "✅ Deployment existe"
    
    # Verificar se pods estão rodando
    POD_STATUS=$(kubectl -n kube-system get pods -l app=k8s-addon --no-headers 2>/dev/null || echo "")
    
    if [[ -n "$POD_STATUS" ]] && echo "$POD_STATUS" | grep -q "Running"; then
        echo "✅ Pods estão rodando"
    elif [[ -n "$POD_STATUS" ]] && echo "$POD_STATUS" | grep -q "ImagePullBackOff"; then
        echo "❌ Problema de ImagePullBackOff detectado"
        echo "🔧 Corrigindo problema de imagem..."
        
        # Rebuild da imagem
        docker build -t k8s-addon:dev .
        
        # Restart do deployment
        kubectl -n kube-system rollout restart deployment/k8s-addon
        kubectl -n kube-system rollout status deployment/k8s-addon --timeout=120s
        
        echo "✅ Problema resolvido"
    else
        echo "⚠️ Pods não estão em estado Running"
        echo "📋 Status atual:"
        kubectl -n kube-system get pods -l app=k8s-addon
        
        echo "🔧 Tentando restart do deployment..."
        kubectl -n kube-system rollout restart deployment/k8s-addon
        kubectl -n kube-system rollout status deployment/k8s-addon --timeout=120s
        echo "✅ Deployment reiniciado"
    fi
fi

echo ""
echo "🎉 Diagnóstico concluído!"
echo "📋 Status final:"
echo "---"
kubectl -n kube-system get deployment k8s-addon
kubectl -n kube-system get pods -l app=k8s-addon
echo ""
echo "💡 Para testar o addon: ./run-tests-only.sh" 