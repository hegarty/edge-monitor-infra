# Edge Monitor Infrastructure

The **Edge Monitor Infrastructure** project provides a, local-first, Kubernetes environment deployed on a Mac using K3d and on a Raspberry Pi running K3s. Designed to support development and deployment of the `edge-monitor-app` (a home WiFi monitoring agent written in Go).

This repository contains:

- A **K3d Kubernetes cluster** for local development on macOS  
- **Prometheus + Grafana** monitoring stack (running in Docker Compose)  
- Kubernetes exporters:
  - **kube-state-metrics**
  - **node-exporter**
- Fully versioned manifests for reproducible environments

This repo **does not** contain the application code.  
That lives here: https://github.com/hegarty/edge-monitor-app

---

# 🌐 Architecture Overview

## Mermaid Diagram

```mermaid
flowchart LR

    subgraph Compose["Docker Compose (Prometheus + Grafana)"]
        P[Prometheus] <--scrapes-->|metrics| KSM
        P <--scrapes-->|metrics| NE
        G[Grafana] <--queries-->|PromQL| P
    end

    subgraph K3d["K3d Kubernetes Cluster"]
        S1[K3s Server Node]
        KSM[kube-state-metrics]
        NE[node-exporter]
    end

    subgraph Host["macOS Host"]
        D[Docker Desktop VM]
        R[Local Registry :5000]
    end

    S1 --> KSM
    S1 --> NE

    P --load balancer ports--> K3d
    D <--runs--> Compose
    D <--runs--> K3d

    edgeApp[edge-monitor-app] --build + push--> R
