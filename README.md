# QuickHaul GitOps Configuration

This repository serves as the **Source of Truth** for the QuickHaul microservices deployment. It utilizes a GitOps pattern with **ArgoCD** for continuous delivery and **Argo Rollouts** for zero-downtime Blue-Green deployments in production.

## 🚀 Architecture Overview

*   **Helm Charts**: Located in `helm-charts/`, providing templated Kubernetes manifests.
*   **Environment Separation**: Managed via `helm-charts/environments/` (Dev vs Prod).
*   **CD Engine**: ArgoCD automates synchronization between this repo and the cluster.
*   **Deployment Strategy**: 
    *   **Dev**: Standard rolling updates (`Deployment`).
    *   **Prod**: Zero-downtime Blue-Green updates (`Rollout`).

---

## 🛠️ Infrastructure Setup

Before connecting this repository to your cluster, you must install the following controllers.

### 1. Install ArgoCD
ArgoCD should be installed in a dedicated namespace. It manages the lifecycle of all applications.

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access the UI (Port-forward for local access)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 2. Install Argo Rollouts
Argo Rollouts is required to handle the Blue-Green deployment strategy used in the production namespace.

```bash
# Create namespace
kubectl create namespace argo-rollouts

# Install Argo Rollouts Controller
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### 3. Node Placement Recommendation
Since you have **1 Master and 2 Worker nodes**:
*   **Master Node**: Keep this dedicated to the Kubernetes Control Plane (API Server, Scheduler, etc.). This ensures stability for the cluster core.
*   **Worker Nodes**: Both ArgoCD and Argo Rollouts should be scheduled on your **Worker Nodes**. Kubernetes does this by default if your master node is tainted. These components are critical but are still considered workloads.

---

## 📦 Connecting to ArgoCD

Once the controllers are installed, you can bootstrap the entire QuickHaul stack by applying the application manifests:

### Dev Environment
```bash
kubectl apply -f argocd-apps/dev-apps.yaml
```

### Prod Environment
```bash
kubectl apply -f argocd-apps/prod-apps.yaml
```

---

## 🔐 Security & OIDC

### Keycloak Integration
The microservices are configured to use Keycloak for OIDC authentication. The configuration is managed in `helm-charts/global-values.yaml`.

*   **Issuer URL**: `https://auth.quickhaul.com/auth/realms/QuickHaul`
*   **Client ID**: `quickhaul-services`

### Automated Image Updates (No Secrets)
This repository supports **OIDC-based image updates**. Application repositories (like `notification-service`) can update their image tags here without using static GitHub Secrets by utilizing the `.github/workflows/oidc-image-update.yml` workflow.

---

## 🔄 Development Workflow

1.  **Code Change**: Developers push to microservice repositories.
2.  **CI**: GitHub Actions builds the image and pushes to Docker Hub.
3.  **CD Trigger**: CI triggers the `oidc-image-update` workflow in this repo.
4.  **GitOps**: ArgoCD detects the change in `values.yaml` and syncs the cluster.
5.  **Rollout**: If in Prod, Argo Rollouts performs a Blue-Green transition.

---

## 📞 Troubleshooting

*   **Check Rollout Status**: `kubectl argo rollouts get rollout <service-name> -n quickhaul-prod`
*   **ArgoCD Sync Issues**: Check the ArgoCD UI or logs: `kubectl logs -n argocd deployment/argocd-repo-server`
