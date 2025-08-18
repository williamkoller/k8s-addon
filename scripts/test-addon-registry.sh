#!/usr/bin/env bash
set -euo pipefail

# ===== Config =====
IMAGE="${IMAGE:-}"                  # ex: ghcr.io/seu-usuario/k8s-addon:dev  (OBRIGATÓRIO)
NAMESPACE="${NAMESPACE:-kube-system}"
DEPLOY="${DEPLOY:-k8s-addon}"
SA_NAME="${SA_NAME:-k8s-addon}"

if [[ -z "${IMAGE}" ]]; then
  echo "❗ Precisa setar a variável IMAGE. Ex.:"
  echo "   IMAGE=ghcr.io/<user>/k8s-addon:dev ./test-addon-registry.sh"
  exit 1
fi

echo "🐳 Buildando e publicando imagem: ${IMAGE}"
docker build -t "${IMAGE}" .
docker push "${IMAGE}"

echo "🔑 Aplicando RBAC base..."
kubectl apply -f manifests/rbac.yaml

echo "🔎 Checando permissão de Leases (leader election)..."
if ! kubectl auth can-i --as=system:serviceaccount:${NAMESPACE}:${SA_NAME} create leases coordination.k8s.io >/dev/null 2>&1; then
  echo "⚠️  Sem permissão de leases. Aplicando papel extra (k8s-addon-leases)..."
  cat <<'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-addon-leases
rules:
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get","list","watch","create","update","patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-addon-leases
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k8s-addon-leases
subjects:
  - kind: ServiceAccount
    name: k8s-addon
    namespace: kube-system
YAML
else
  echo "✅ Permissão de leases OK."
fi

echo "🚀 Aplicando Deployment (se ainda não existir) e setando imagem..."
kubectl apply -f manifests/deployment.yaml
kubectl -n "${NAMESPACE}" set image deploy/${DEPLOY} addon="${IMAGE}" --record=true

echo "⏳ Aguardando rollout..."
kubectl -n "${NAMESPACE}" rollout status deploy/${DEPLOY}

echo "📦 Criando namespace de teste (declarativo)..."
kubectl create ns teste-addon --dry-run=client -o yaml | kubectl apply -f -
echo -n "🔍 Label 'owner' no namespace: "
kubectl get ns teste-addon -o jsonpath='{.metadata.labels.owner}'; echo

echo "💻 Selecionando um nó para o teste..."
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
echo "Node alvo: ${NODE}"

echo "🏷️ Rotulando o node com gpu=true..."
kubectl label node "${NODE}" gpu=true --overwrite || true

echo "🔍 Conferindo taints do node..."
if command -v jq >/dev/null 2>&1; then
  kubectl get node "${NODE}" -o json | jq '.spec.taints'
else
  echo "(jq não encontrado — usando jsonpath)"
  kubectl get node "${NODE}" -o jsonpath='{.spec.taints}'; echo
fi

echo "✅ Fluxo concluído."
