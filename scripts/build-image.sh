#!/usr/bin/env bash
set -euo pipefail

# Script para build da imagem Docker do k8s-addon
# Uso: ./build-image.sh [IMAGE_NAME]

IMAGE_NAME="${1:-k8s-addon:dev}"

echo "🐳 Buildando imagem Docker: $IMAGE_NAME"

# Verificar se Dockerfile existe
if [[ ! -f "Dockerfile" ]]; then
    echo "❌ Dockerfile não encontrado no diretório atual"
    exit 1
fi

# Verificar se Minikube está rodando
if ! minikube status >/dev/null 2>&1; then
    echo "❌ Minikube não está rodando. Execute 'minikube start' primeiro."
    exit 1
fi

# Configurar Docker para usar daemon do Minikube
echo "🔧 Configurando Docker para Minikube..."
eval $(minikube docker-env)

# Build da imagem
echo "📦 Executando docker build no contexto Minikube..."
docker build -t "$IMAGE_NAME" .

echo "✅ Imagem buildada com sucesso: $IMAGE_NAME"

# Verificar se a imagem foi criada
if docker images "$IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    echo "✅ Imagem confirmada no Docker local"
else
    echo "❌ Erro: Imagem não foi encontrada após o build"
    exit 1
fi 