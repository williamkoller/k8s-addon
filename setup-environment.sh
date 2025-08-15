#!/usr/bin/env bash
set -euo pipefail

# Script para configurar ambiente Docker com Minikube
# Uso: ./setup-environment.sh

echo "🔧 Configurando ambiente Docker para Minikube..."

# Verificar se Minikube está rodando
if ! minikube status >/dev/null 2>&1; then
    echo "❌ Minikube não está rodando. Iniciando..."
    minikube start
    echo "✅ Minikube iniciado com sucesso"
else
    echo "✅ Minikube já está rodando"
fi

# Configurar Docker para usar o daemon do Minikube
echo "🐳 Apontando Docker para o daemon do Minikube..."
eval $(minikube docker-env)

echo "✅ Ambiente configurado com sucesso!"
echo "💡 Docker agora está apontando para o daemon do Minikube" 