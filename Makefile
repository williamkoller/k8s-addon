APP            ?= k8s-addon
IMAGE          ?= k8s-addon:dev
NAMESPACE      ?= kube-system
KUBECTL        ?= kubectl

deps:
	go mod download
tidy:
	go mod tidy
build:
	CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o bin/$(APP) ./cmd/addon
run:
	go run ./cmd/addon
test:
	go test ./... -count=1
docker-build:
	docker build -t $(IMAGE) .
docker-push:
	docker push $(IMAGE)
deploy: rbac set-image apply
rbac:
	$(KUBECTL) apply -f manifests/rbac.yaml
set-image:
	sed -E -i.bak 's|image: .*|image: $(IMAGE)|' manifests/deployment.yaml
apply:
	$(KUBECTL) apply -f manifests/deployment.yaml
uninstall:
	-$(KUBECTL) -n $(NAMESPACE) delete deploy/$(APP)
	-$(KUBECTL) delete -f manifests/rbac.yaml
logs:
	$(KUBECTL) -n $(NAMESPACE) logs -l app=$(APP) --tail=200 -f
pf:
	$(KUBECTL) -n $(NAMESPACE) port-forward deploy/$(APP) 8081:8081
test-ns:
	-$(KUBECTL) create ns teste-addon
	sleep 1
	$(KUBECTL) get ns teste-addon -o jsonpath='{.metadata.labels.owner}'; echo
NODE ?=
test-node:
ifndef NODE
	$(error Use: make test-node NODE=<nome-do-node>)
endif
	$(KUBECTL) label node $(NODE) gpu=true --overwrite
	sleep 1
	$(KUBECTL) get node $(NODE) -o json | jq '.spec.taints'
