# Kubernetes Cluster Monitoring

A production-ready monitoring stack for Kubernetes clusters using **Prometheus**, **Grafana**, **Alertmanager**, **kube-state-metrics**, and **node-exporter**.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  Kubernetes Cluster                       │
│                                                          │
│  ┌──────────────┐   scrape    ┌──────────────────────┐  │
│  │ node-exporter├────────────►│                      │  │
│  │  (DaemonSet) │             │     Prometheus       │  │
│  └──────────────┘             │                      │  │
│                               │  - Scrape configs    │  │
│  ┌──────────────┐   scrape    │  - Alert rules       │  │
│  │ kube-state-  ├────────────►│  - 15-day retention  │  │
│  │   metrics    │             │                      │  │
│  └──────────────┘             └──────┬───────┬───────┘  │
│                                      │       │          │
│                               query  │       │ alerts   │
│                                      ▼       ▼          │
│                              ┌───────────┐ ┌──────────┐ │
│                              │  Grafana  │ │Alertmgr  │ │
│                              │           │ │          │ │
│                              │ Dashboards│ │ Slack /  │ │
│                              │ & Graphs  │ │ Email    │ │
│                              └───────────┘ └──────────┘ │
└──────────────────────────────────────────────────────────┘
```

## Components

| Component | Version | Purpose |
|---|---|---|
| Prometheus | v2.51.0 | Metrics collection, storage, and alerting engine |
| Grafana | v10.4.1 | Visualization and dashboarding |
| Alertmanager | v0.27.0 | Alert routing, grouping, and notifications |
| node-exporter | v1.7.0 | Host-level metrics (CPU, memory, disk, network) |
| kube-state-metrics | v2.12.0 | Kubernetes object metrics (pods, deployments, nodes) |


## Prerequisites

- A running Kubernetes cluster (minikube, kind, EKS, GKE, AKS, etc.)
- `kubectl` configured to talk to the cluster
- Cluster admin permissions (needed for ClusterRole/ClusterRoleBinding)

## Quick Start

### 1. Deploy the entire stack

```bash
cd k8s-monitoring
./deploy.sh deploy
```

### 2. Check status

```bash
./deploy.sh status
```

### 3. Access the UIs

**Option A: NodePort** (if your cluster exposes NodePorts)

| Service | URL |
|---|---|
| Prometheus | `http://<node-ip>:30090` |
| Grafana | `http://<node-ip>:30030` |
| Alertmanager | `http://<node-ip>:30093` |

**Option B: Port-forward** (works everywhere)

```bash
# In separate terminals:
kubectl -n monitoring port-forward svc/prometheus 9090:9090
kubectl -n monitoring port-forward svc/grafana 3000:3000
kubectl -n monitoring port-forward svc/alertmanager 9093:9093
```

Then open:
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (login: `admin` / `admin`)
- Alertmanager: http://localhost:9093

### 4. Tear down

```bash
./deploy.sh teardown
```

## What Gets Scraped

Prometheus is pre-configured to scrape:

| Target | Job Name | Metrics |
|---|---|---|
| Prometheus itself | `prometheus` | Internal Prometheus metrics |
| Kubernetes API server | `kubernetes-apiservers` | API request latencies, etcd stats |
| Kubelet | `kubernetes-nodes` | Node-level kubelet metrics |
| cAdvisor | `kubernetes-cadvisor` | Container CPU, memory, network, disk |
| Service endpoints | `kubernetes-service-endpoints` | Any service with `prometheus.io/scrape: "true"` |
| Pods | `kubernetes-pods` | Any pod with `prometheus.io/scrape: "true"` |
| node-exporter | `node-exporter` | Host CPU, memory, disk, network, filesystem |
| kube-state-metrics | `kube-state-metrics` | Pod status, deployment replicas, node conditions |

### Adding Your Own Application Metrics

Annotate your pod or service to be auto-discovered:

```yaml
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
    prometheus.io/path: "/metrics"    # default: /metrics
    prometheus.io/scheme: "http"      # default: http
```

## Alert Rules

Pre-configured alerts covering the most important failure modes:

### Node Alerts
| Alert | Condition | Severity |
|---|---|---|
| NodeHighCPU | CPU > 80% for 5m | warning |
| NodeCriticalCPU | CPU > 95% for 2m | critical |
| NodeHighMemory | Memory > 85% for 5m | warning |
| NodeDiskSpaceLow | Disk > 85% for 10m | warning |
| NodeDiskSpaceCritical | Disk > 95% for 5m | critical |
| NodeNotReady | Node NotReady for 2m | critical |

### Pod Alerts
| Alert | Condition | Severity |
|---|---|---|
| PodCrashLooping | Restarts in last 15m | warning |
| PodNotReady | Not ready for 10m | warning |
| ContainerOOMKilled | OOMKilled termination | warning |
| PodHighCPUUsage | > 90% of CPU limit | warning |
| PodHighMemoryUsage | > 90% of memory limit | warning |

### Deployment Alerts
| Alert | Condition | Severity |
|---|---|---|
| DeploymentReplicasMismatch | Desired != ready for 10m | warning |
| DeploymentGenerationMismatch | Rollout stuck for 10m | critical |

### Other Alerts
| Alert | Condition | Severity |
|---|---|---|
| PVCAlmostFull | PVC > 85% full | warning |
| PrometheusTargetDown | Scrape target unreachable for 5m | warning |
| PrometheusConfigReloadFailed | Config reload failed | critical |

## Grafana Dashboards

Two dashboards are provisioned automatically:

### Kubernetes Cluster Overview
- Total nodes, pods, namespaces, deployments, failed pods, firing alerts
- Node CPU and memory usage over time
- Network I/O per node
- Disk usage per node
- Top 10 pods by CPU and memory consumption
- Pod restarts in the last hour
- Pods by phase (table)

### Node Details
- Template variable `$node` to filter by specific node(s)
- CPU usage, CPU by mode (user/system/iowait/etc.), load averages
- Memory breakdown (used, buffers, cached, free) and usage gauge
- Disk usage by mountpoint, disk I/O read/write
- Network bandwidth and errors/drops per interface

## Configuring Notifications

### Slack Integration

Edit `alertmanager/alertmanager-configmap.yaml`:

1. Set the global Slack webhook URL:
   ```yaml
   global:
     slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
   ```

2. Uncomment the `slack_configs` blocks in the receivers section.

3. Re-apply:
   ```bash
   kubectl apply -f alertmanager/alertmanager-configmap.yaml
   kubectl -n monitoring rollout restart deployment/alertmanager
   ```

### Email Integration

Edit `alertmanager/alertmanager-configmap.yaml`:

1. Set the SMTP settings in the `global` section:
   ```yaml
   global:
     smtp_smarthost: 'smtp.gmail.com:587'
     smtp_from: 'alertmanager@example.com'
     smtp_auth_username: 'your-email@gmail.com'
     smtp_auth_password: 'your-app-password'
     smtp_require_tls: true
   ```

2. Uncomment the `email_configs` blocks in the receivers section.

3. Re-apply:
   ```bash
   kubectl apply -f alertmanager/alertmanager-configmap.yaml
   kubectl -n monitoring rollout restart deployment/alertmanager
   ```

### PagerDuty, OpsGenie, etc.

Alertmanager supports many more receivers. See the [Alertmanager documentation](https://prometheus.io/docs/alerting/latest/configuration/) for the full list.

## Customization

### Adjust Scrape Intervals

Edit `prometheus/prometheus-configmap.yaml` and change:
```yaml
global:
  scrape_interval: 15s      # How often to scrape targets
  evaluation_interval: 15s  # How often to evaluate alert rules
```

### Adjust Data Retention

Edit the Prometheus deployment args in `prometheus/prometheus-deployment.yaml`:
```yaml
args:
  - "--storage.tsdb.retention.time=15d"  # Change to desired retention
```

### Add Persistent Storage

Replace `emptyDir: {}` volumes in the Prometheus and Grafana deployments with `PersistentVolumeClaim`:

```yaml
volumes:
  - name: prometheus-storage
    persistentVolumeClaim:
      claimName: prometheus-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: monitoring
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 50Gi
```

### Use Ingress Instead of NodePort

Replace NodePort services with ClusterIP and add an Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: monitoring-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
    - host: grafana.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: grafana
                port:
                  number: 3000
```

## Troubleshooting

```bash
# Check pod logs
kubectl -n monitoring logs deployment/prometheus
kubectl -n monitoring logs deployment/grafana
kubectl -n monitoring logs deployment/alertmanager

# Check Prometheus targets
# Open Prometheus UI → Status → Targets
# Or: curl http://localhost:9090/api/v1/targets

# Check Prometheus alerts
# Open Prometheus UI → Alerts
# Or: curl http://localhost:9090/api/v1/alerts

# Check Alertmanager status
# curl http://localhost:9093/api/v2/status

# Restart a component after config change
kubectl -n monitoring rollout restart deployment/prometheus
kubectl -n monitoring rollout restart deployment/grafana
kubectl -n monitoring rollout restart deployment/alertmanager
```

## Production Considerations

- **Persistent storage**: Use PVCs instead of `emptyDir` for Prometheus and Grafana data
- **Resource limits**: Adjust CPU/memory limits based on cluster size
- **High availability**: Run multiple Prometheus replicas with Thanos or Cortex
- **Security**: Use Kubernetes Secrets for Grafana admin password and SMTP credentials
- **Network policies**: Restrict traffic between monitoring components
- **TLS**: Enable HTTPS on Prometheus, Grafana, and Alertmanager
- **RBAC**: Scope Prometheus RBAC to specific namespaces if full cluster access is not needed

