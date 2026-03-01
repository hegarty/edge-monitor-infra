.PHONY: k3d-up k3d-down k3s-up k3s-down prometheus-up prometheus-down

k3d-up:
	k3d cluster create --config k3d-mac/cluster.yaml
	kubectl wait --for=condition=Ready node --all --timeout=60s
	kubectl apply -f manifests/namespaces/
	kubectl apply -f manifests/secrets/
	kubectl apply -f manifests/kube-state-metrics/
	kubectl apply -f manifests/node-exporter/
	kubectl apply -f manifests/ingress/

k3d-down:
	k3d cluster delete edge-dev

k3s-up:
	@echo "Not yet implemented — see k3s bootstrap branch"

k3s-down:
	@echo "Not yet implemented — see k3s bootstrap branch"

prometheus-up:
	docker compose -f compose/docker-compose.yml up -d

prometheus-down:
	docker compose -f compose/docker-compose.yml down
