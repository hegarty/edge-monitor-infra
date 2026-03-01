project:
  name: edge-monitor-infra
  description: >
    Infrastructure repository for the Edge Monitor platform.
    Defines cluster runtimes and cluster-level configuration.
    Application logic and Helm charts live in edge-monitor-app.

architecture:
  separation_of_concerns:
    edge-monitor-infra:
      owns:
        - k3d cluster provisioning
        - k3s cluster provisioning
        - namespace creation
        - cluster-level networking
        - ingress controllers
        - secrets scaffolding
        - prometheus/grafana (infra observability)
        - raspberry-pi bootstrap
    edge-monitor-app:
      owns:
        - golang applications
        - dockerfiles
        - multi-arch image builds
        - helm charts
        - application configuration
        - per-app kubernetes manifests

  helm_strategy:
    location: edge-monitor-app
    reasoning: >
      Deployment configuration should live with the application logic.
      Helm charts version alongside code to prevent drift between
      infra and app definitions.
    infra_repo_does_not_contain:
      - application helm charts
      - application manifests

runtimes:

  docker:
    type: local-container
    purpose:
      - rapid container testing
      - debugging without kubernetes
    architecture: amd64
    production_like: false

  k3d:
    type: kubernetes
    environment: local-development
    distribution: k3s (via k3d)
    architecture: amd64
    purpose:
      - authoritative development cluster
      - validate helm charts
      - simulate production behavior
    namespace_strategy:
      isolate_apps: true
      namespaces:
        - wifi-probe
        - dns-probe
        - jitter-probe
        - gateway-monitor
        - hello-world
      reasoning: >
        Each application runs in its own namespace to:
          - isolate resources
          - simplify debugging
          - prevent accidental cross-service interference
          - allow per-app RBAC in the future
    requirements:
      - k3d must mirror k3s as closely as possible
      - all helm charts must succeed here before k3s deployment

  k3s:
    type: kubernetes
    environment: edge-production
    distribution: k3s
    architecture: arm64
    hardware:
      target: raspberry-pi
    purpose:
      - production edge runtime
      - network monitoring at the wifi boundary
    system_requirements:
      swap_disabled: true
      container_runtime: containerd
      persistent_storage: configurable
      auto_restart_on_reboot: true
    networking:
      tolerate_intermittent_connectivity: true
      prefer_local_buffering: true

k3s_components:
  api_server:
    purpose: >
      Central control plane interface for kubectl and cluster state management.
  scheduler:
    purpose: >
      Assigns pods to nodes based on available resources.
  controller_manager:
    purpose: >
      Maintains desired cluster state (replicas, endpoints, nodes).
  containerd:
    purpose: >
      Lightweight container runtime used by k3s.
  kubelet:
    purpose: >
      Runs on each node and ensures containers are healthy.
  flannel:
    purpose: >
      Default lightweight overlay network for pod communication.
  core_dns:
    purpose: >
      Provides internal cluster DNS resolution.

multi_arch_build:
  strategy: docker-buildx
  platforms:
    - linux/amd64
    - linux/arm64
  requirements:
    - single Dockerfile per app
    - immutable tags
    - push once, run everywhere
    - no runtime-specific images

makefile:
  location: edge-monitor-infra
  purpose: >
    Provide simple operational commands for managing
    k3d and k3s clusters and local observability stack.

  targets:

    k3d-up:
      description: "Create local k3d cluster with predefined namespaces."

    k3d-down:
      description: "Destroy local k3d cluster."

    k3s-up:
      description: >
        Install or start k3s cluster on Raspberry Pi.
        Ensures required components are active.

    k3s-down:
      description: >
        Stop k3s services cleanly without removing configuration.

    prometheus-up:
      description: >
        Start Prometheus and Grafana via docker-compose
        for local infrastructure observability.

    prometheus-down:
      description: >
        Stop Prometheus and Grafana containers.

observability:

  cluster_level:
    managed_by: edge-monitor-infra
    stack:
      - prometheus
      - grafana
    runtime: docker-compose (local dev)
    future:
      - remote edge metrics aggregation

  app_level:
    managed_by: edge-monitor-app
    requirements:
      - readiness probes
      - liveness probes
      - stdout logging
      - metrics endpoint (if applicable)

deployment_philosophy:
  build_once: true
  helm_with_app_code: true
  infra_manages_cluster_only: true
  isolate_apps_by_namespace: true
  treat_k3s_as_production: true
  k3d_mirrors_k3s: true
  arm64_support_mandatory: true
  survive_reboot_without_manual_intervention: true

future_roadmap:
  - ota_updates_for_raspberry_pi
  - centralized_edge_dashboard
  - secure_remote_cluster_reporting
  - wifi_instability_detection
  - persistent_metrics_storage
