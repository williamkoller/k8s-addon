#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Apontando Docker para Minikube..."
eval $(minikube docker-env)

echo "🐳 Buildando imagem local..."
docker build -t k8s-addon:dev .

echo "🔑 Aplicando RBAC..."
kubectl apply -f manifests/rbac.yaml

echo "🚀 Deploy/Restart do addon..."
# garante que o deployment use a imagem correta
sed -E -i.bak 's|image: .*|image: k8s-addon:dev|' manifests/deployment.yaml
kubectl apply -f manifests/deployment.yaml
kubectl -n kube-system rollout restart deploy/k8s-addon
kubectl -n kube-system rollout status deploy/k8s-addon

echo "📦 Criando namespace de teste..."
kubectl create ns teste-addon --dry-run=client -o yaml | kubectl apply -f -
echo -n "Label 'owner' no namespace: "
kubectl get ns teste-addon -o jsonpath='{.metadata.labels.owner}'; echo

echo "💻 Pegando nome do primeiro node..."
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Node alvo: $NODE"

echo "🏷️ Rotulando node com gpu=true..."
kubectl label node "$NODE" gpu=true --overwrite || true

echo "🔍 Conferindo taints..."
kubectl get node "$NODE" -o json | jq '.spec.taints'

echo "✅ Teste concluído."
