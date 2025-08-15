#!/usr/bin/env bash
set -euo pipefail

# Script principal para executar todo o pipeline do k8s-addon
# Uso: ./run-all.sh [IMAGE_NAME]

IMAGE_NAME="${1:-k8s-addon:dev}"

echo "🚀 Iniciando pipeline completo do k8s-addon"
echo "📦 Imagem: $IMAGE_NAME"
echo "=====================================\n"

# 1. Configurar ambiente
echo "ETAPA 1: Configurando ambiente..."
./setup-environment.sh
echo ""

# 2. Build da imagem
echo "ETAPA 2: Build da imagem..."
./build-image.sh "$IMAGE_NAME"
echo ""

# 3. Deploy RBAC
echo "ETAPA 3: Aplicando RBAC..."
./deploy-rbac.sh
echo ""

# 4. Deploy da aplicação
echo "ETAPA 4: Deploy da aplicação..."
./deploy-addon.sh "$IMAGE_NAME"
echo ""

# Aguardar controladores ficarem prontos
echo "⏳ Aguardando controladores ficarem prontos..."
./wait-for-controllers.sh

# 5. Testes
echo "ETAPA 5: Executando testes..."
echo "🧪 Testando NamespaceController..."
./test-namespace.sh
echo ""

echo "🧪 Testando NodeController..."
./test-node.sh
echo ""

echo "=====================================\n"
echo "✅ Pipeline completo executado com sucesso!"
echo ""
echo "📋 Comandos úteis:"
echo "  - Ver logs: kubectl -n kube-system logs -l app=k8s-addon -f"
echo "  - Ver pods: kubectl -n kube-system get pods -l app=k8s-addon"
echo "  - Cleanup: ./cleanup.sh"
echo "  - Métricas: kubectl -n kube-system port-forward deploy/k8s-addon 8080:8080"
echo "  - Health: kubectl -n kube-system port-forward deploy/k8s-addon 8081:8081" 