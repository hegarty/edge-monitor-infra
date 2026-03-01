#!/usr/bin/env bash
#
# Rebuilds the k3d edge-dev cluster with the local registry connected.
#
# Usage:
#   ./scripts/rebuild-cluster.sh
#
# What this does:
#   1. Deletes the existing edge-dev cluster (if any)
#   2. Ensures the k3d-edge-registry is running
#   3. Recreates the cluster with --registry-use so containerd
#      can pull from k3d-edge-registry:5000 over HTTP
#   4. Applies namespace manifests and infra components
#
set -euo pipefail

INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTER_NAME="edge-dev"
REGISTRY_NAME="k3d-edge-registry"
REGISTRY_PORT=5000

echo "=== Rebuild k3d cluster: ${CLUSTER_NAME} ==="

# -----------------------------------------------
# 1. Delete existing cluster
# -----------------------------------------------
if k3d cluster list | grep -q "${CLUSTER_NAME}"; then
    echo ">> Deleting existing cluster ${CLUSTER_NAME}"
    k3d cluster delete "${CLUSTER_NAME}"
else
    echo ">> No existing cluster ${CLUSTER_NAME} found"
fi

# -----------------------------------------------
# 2. Ensure registry is running
# -----------------------------------------------
if k3d registry list | grep -q "${REGISTRY_NAME}"; then
    echo ">> Registry ${REGISTRY_NAME} already exists"
else
    echo ">> Creating registry ${REGISTRY_NAME} on port ${REGISTRY_PORT}"
    k3d registry create edge-registry --port "${REGISTRY_PORT}"
fi

# -----------------------------------------------
# 3. Create cluster with registry connected
# -----------------------------------------------
echo ">> Creating cluster ${CLUSTER_NAME} with registry ${REGISTRY_NAME}:${REGISTRY_PORT}"
k3d cluster create --config "${INFRA_DIR}/k3d-mac/cluster.yaml"

# -----------------------------------------------
# 4. Wait for node readiness
# -----------------------------------------------
echo ">> Waiting for nodes to be ready"
kubectl wait --for=condition=Ready node --all --timeout=60s

# -----------------------------------------------
# 5. Apply namespaces and infra manifests
# -----------------------------------------------
echo ">> Applying namespace manifests"
kubectl apply -f "${INFRA_DIR}/manifests/namespaces/"

echo ">> Applying secrets"
kubectl apply -f "${INFRA_DIR}/manifests/secrets/"

echo ">> Applying kube-state-metrics"
kubectl apply -f "${INFRA_DIR}/manifests/kube-state-metrics/"

echo ">> Applying node-exporter"
kubectl apply -f "${INFRA_DIR}/manifests/node-exporter/"

echo ">> Waiting for Traefik deployment to appear"
for i in $(seq 1 30); do
    if kubectl get deployment traefik -n kube-system >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
echo ">> Waiting for Traefik to be ready"
kubectl wait --for=condition=Available deployment/traefik -n kube-system --timeout=120s

echo ">> Applying ingress and middleware"
kubectl apply -f "${INFRA_DIR}/manifests/ingress/"

# -----------------------------------------------
# 6. Verify
# -----------------------------------------------
echo ""
echo "=== Cluster ready ==="
echo ""
kubectl cluster-info
echo ""
kubectl get namespaces
echo ""
echo "Registry: http://localhost:${REGISTRY_PORT}/v2/_catalog"
echo ""
echo "Next steps:"
echo "  cd /Users/terencehegarty/projects/hegarty/edge-monitor-app"
echo "  cd wifi-probe && make deploy"
echo "  cd dns-probe && make deploy"
echo "  cd jitter-probe && make deploy"
echo "  cd gateway-monitor && make deploy"
