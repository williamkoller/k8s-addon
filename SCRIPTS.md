# 📋 Scripts Modulares do k8s-addon

Este diretório contém scripts modulares para gerenciar o deployment e testes do k8s-addon no Kubernetes.

## 🎯 Scripts Disponíveis

### 📋 Scripts Principais

| Script                 | Descrição                                                             | Uso                         |
| ---------------------- | --------------------------------------------------------------------- | --------------------------- |
| `run-all.sh`           | **Pipeline completo** - Executa todo o processo do zero               | `./run-all.sh [IMAGE_NAME]` |
| `run-tests-only.sh`    | **Apenas testes** - Executa testes assumindo addon já deployado       | `./run-tests-only.sh`       |
| `fix-common-issues.sh` | **Diagnóstico e correção** - Resolve problemas comuns automaticamente | `./fix-common-issues.sh`    |
| `cleanup.sh`           | **Limpeza** - Remove addon e recursos do cluster                      | `./cleanup.sh`              |

### 🔧 Scripts Modulares

| Script                    | Responsabilidade              | Pré-requisitos       | Uso                                   |
| ------------------------- | ----------------------------- | -------------------- | ------------------------------------- |
| `setup-environment.sh`    | Configura Docker com Minikube | Minikube instalado   | `./setup-environment.sh`              |
| `build-image.sh`          | Build da imagem Docker        | Docker + Dockerfile  | `./build-image.sh [IMAGE_NAME]`       |
| `deploy-rbac.sh`          | Aplica permissões RBAC        | kubectl + cluster    | `./deploy-rbac.sh`                    |
| `deploy-addon.sh`         | Deploy da aplicação           | RBAC aplicado        | `./deploy-addon.sh [IMAGE_NAME]`      |
| `wait-for-controllers.sh` | Aguarda controladores prontos | Addon deployado      | `./wait-for-controllers.sh [TIMEOUT]` |
| `test-namespace.sh`       | Testa NamespaceController     | Controladores ativos | `./test-namespace.sh [NAMESPACE]`     |
| `test-node.sh`            | Testa NodeController          | Controladores ativos | `./test-node.sh [NODE_NAME]`          |

## 🚀 Fluxos de Uso

### 🎯 Fluxo Completo (Recomendado)

```bash
# Executa todo o pipeline: setup → build → deploy → testes
./run-all.sh

# Com imagem customizada
./run-all.sh minha-imagem:v1.0.0
```

### 🔧 Fluxo Modular (Para desenvolvimento)

```bash
# 1. Configurar ambiente
./setup-environment.sh

# 2. Build da imagem
./build-image.sh k8s-addon:dev

# 3. Deploy RBAC
./deploy-rbac.sh

# 4. Deploy da aplicação
./deploy-addon.sh k8s-addon:dev

# 5. Aguardar controladores ficarem prontos
./wait-for-controllers.sh

# 6. Executar testes
./test-namespace.sh
./test-node.sh
```

### 🧪 Apenas Testes

```bash
# Se addon já está deployado
./run-tests-only.sh
```

### 🔧 Diagnóstico e Correção

```bash
# Se algo não estiver funcionando
./fix-common-issues.sh
```

### 🗑️ Limpeza

```bash
# Remove tudo do cluster
./cleanup.sh
```

## ⚙️ Configurações

### Variáveis de Ambiente Suportadas

| Variável         | Padrão          | Descrição               |
| ---------------- | --------------- | ----------------------- |
| `IMAGE_NAME`     | `k8s-addon:dev` | Nome da imagem Docker   |
| `NAMESPACE`      | `kube-system`   | Namespace do deployment |
| `TEST_NAMESPACE` | `teste-addon`   | Namespace para testes   |

### Exemplos de Uso com Configurações

```bash
# Usar imagem específica
./run-all.sh ghcr.io/user/k8s-addon:v1.0.0

# Testar com namespace específico
./test-namespace.sh meu-teste

# Testar node específico
./test-node.sh minikube
```

## 🔍 Validações Automáticas

Cada script inclui validações para:

- ✅ **Conectividade** com cluster Kubernetes
- ✅ **Existência** de arquivos necessários
- ✅ **Status** de pré-requisitos
- ✅ **Execução** bem-sucedida de comandos
- ✅ **Estado final** esperado

## 📊 Logs e Feedback

Todos os scripts fornecem:

- 📝 **Logs informativos** com emojis para facilitar leitura
- ✅ **Confirmações** de sucesso
- ❌ **Mensagens de erro** claras
- 💡 **Dicas** para resolução de problemas

## 🐛 Troubleshooting

### Problemas Comuns

**Script não executável:**

```bash
chmod +x *.sh
```

**Minikube não encontrado:**

```bash
# Instalar Minikube primeiro
# https://minikube.sigs.k8s.io/docs/start/
```

**kubectl não configurado:**

```bash
# Verificar configuração
kubectl cluster-info
```

**Imagem não encontrada:**

```bash
# Verificar se Docker está apontando para Minikube
eval $(minikube docker-env)
docker images
```

### Debug Avançado

```bash
# Ver logs do addon
kubectl -n kube-system logs -l app=k8s-addon -f

# Health checks
kubectl -n kube-system port-forward deploy/k8s-addon 8081:8081
curl http://localhost:8081/healthz

# Métricas
kubectl -n kube-system port-forward deploy/k8s-addon 8080:8080
curl http://localhost:8080/metrics
```

## 🔗 Compatibilidade

- ✅ **bash** 4.0+
- ✅ **kubectl** 1.30+
- ✅ **docker** 20.0+
- ✅ **minikube** 1.30+
- ✅ **jq** (para parsing JSON)

## 💡 Dicas de Uso

1. **Execute sempre** `./run-all.sh` para primeiro deploy
2. **Use scripts modulares** para desenvolvimento iterativo
3. **Se algo der errado**, execute `./fix-common-issues.sh` primeiro
4. **Execute** `./cleanup.sh` antes de re-deployar
5. **Monitore logs** em outra janela durante testes
6. **Mantenha backup** dos manifestos antes de modificar
