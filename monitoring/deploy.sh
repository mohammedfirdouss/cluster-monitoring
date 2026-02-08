#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Pre-flight checks ──────────────────────────────────────
check_prerequisites() {
  if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
  fi

  if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to a Kubernetes cluster. Ensure your kubeconfig is set."
    exit 1
  fi

  info "Connected to cluster: $(kubectl cluster-info 2>/dev/null | head -1)"
}

# ── Create ConfigMaps from dashboard JSON files ────────────
create_dashboard_configmaps() {
  info "Creating Grafana dashboard ConfigMaps..."

  kubectl create configmap grafana-dashboard-cluster \
    --from-file="${SCRIPT_DIR}/grafana/dashboards/cluster-overview.json" \
    -n monitoring --dry-run=client -o yaml | kubectl apply -f -

  kubectl create configmap grafana-dashboard-node \
    --from-file="${SCRIPT_DIR}/grafana/dashboards/node-details.json" \
    -n monitoring --dry-run=client -o yaml | kubectl apply -f -
}

# ── Deploy ──────────────────────────────────────────────────
deploy() {
  check_prerequisites

  info "Creating monitoring namespace..."
  kubectl apply -f "${SCRIPT_DIR}/namespace/namespace.yaml"

  info "Applying RBAC resources..."
  kubectl apply -f "${SCRIPT_DIR}/rbac/"

  info "Deploying kube-state-metrics..."
  kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/"

  info "Deploying node-exporter..."
  kubectl apply -f "${SCRIPT_DIR}/node-exporter/"

  info "Deploying Prometheus..."
  kubectl apply -f "${SCRIPT_DIR}/prometheus/"

  info "Deploying Alertmanager..."
  kubectl apply -f "${SCRIPT_DIR}/alertmanager/"

  info "Deploying Grafana provisioning configs..."
  kubectl apply -f "${SCRIPT_DIR}/grafana/provisioning/"

  create_dashboard_configmaps

  info "Deploying Grafana..."
  kubectl apply -f "${SCRIPT_DIR}/grafana/grafana-deployment.yaml"

  echo ""
  info "Deployment complete! Waiting for pods to become ready..."
  kubectl -n monitoring rollout status deployment/prometheus --timeout=120s 2>/dev/null || true
  kubectl -n monitoring rollout status deployment/grafana --timeout=120s 2>/dev/null || true
  kubectl -n monitoring rollout status deployment/alertmanager --timeout=120s 2>/dev/null || true

  echo ""
  info "============================================"
  info "  Monitoring Stack Deployed Successfully"
  info "============================================"
  info ""
  info "Access URLs (NodePort):"
  info "  Prometheus:    http://<node-ip>:30090"
  info "  Grafana:       http://<node-ip>:30030  (admin/admin)"
  info "  Alertmanager:  http://<node-ip>:30093"
  info ""
  info "Port-forward alternative:"
  info "  kubectl -n monitoring port-forward svc/prometheus 9090:9090"
  info "  kubectl -n monitoring port-forward svc/grafana 3000:3000"
  info "  kubectl -n monitoring port-forward svc/alertmanager 9093:9093"
  info ""
}

# ── Teardown ────────────────────────────────────────────────
teardown() {
  check_prerequisites

  warn "This will delete ALL monitoring resources."
  read -rp "Are you sure? [y/N]: " confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }

  info "Deleting monitoring namespace and all resources..."
  kubectl delete namespace monitoring --ignore-not-found

  info "Deleting cluster-level RBAC..."
  kubectl delete clusterrole prometheus kube-state-metrics --ignore-not-found
  kubectl delete clusterrolebinding prometheus kube-state-metrics --ignore-not-found

  info "Teardown complete."
}

# ── Status ──────────────────────────────────────────────────
status() {
  check_prerequisites

  echo ""
  info "=== Monitoring Namespace Pods ==="
  kubectl -n monitoring get pods -o wide 2>/dev/null || warn "Namespace 'monitoring' not found."

  echo ""
  info "=== Monitoring Services ==="
  kubectl -n monitoring get svc 2>/dev/null || true

  echo ""
  info "=== Monitoring Deployments ==="
  kubectl -n monitoring get deployments 2>/dev/null || true

  echo ""
  info "=== Monitoring DaemonSets ==="
  kubectl -n monitoring get daemonsets 2>/dev/null || true
}

# ── Main ────────────────────────────────────────────────────
case "${1:-}" in
  deploy)   deploy ;;
  teardown) teardown ;;
  status)   status ;;
  *)
    echo "Usage: $0 {deploy|teardown|status}"
    exit 1
    ;;
esac
