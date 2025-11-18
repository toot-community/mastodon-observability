JSONNET ?= jsonnet
JSONNET_FMT ?= jsonnetfmt
JSONNET_LINT ?= jsonnet-lint
PROMTOOL ?= promtool
KUBECTL ?= kubectl
KUSTOMIZE ?= kustomize
ENV ?= production

.PHONY: generate lint apply clean dashboards alerts

generate:
	@mkdir -p generated/alerts generated/dashboards
	$(JSONNET) -J lib -m generated envs/$(ENV).jsonnet

lint: generate
	@find lib envs -type f \( -name '*.libsonnet' -o -name '*.jsonnet' \) -print0 | while IFS= read -r -d '' file; do $(JSONNET_FMT) -n 2 -i "$$file"; done
	@command -v $(JSONNET_LINT) >/dev/null 2>&1 && find lib envs -type f \( -name '*.libsonnet' -o -name '*.jsonnet' \) -print0 | while IFS= read -r -d '' file; do $(JSONNET_LINT) "$$file"; done || echo "jsonnet-lint not found, skipping"
	$(PROMTOOL) check rules generated/alerts/*.promtool.yaml

apply: generate
	$(KUSTOMIZE) build --load-restrictor=LoadRestrictionsNone deploy | $(KUBECTL) apply -f -

clean:
	rm -rf generated
