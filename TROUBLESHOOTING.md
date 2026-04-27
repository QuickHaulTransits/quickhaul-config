# QuickHaul Kubernetes Cluster Troubleshooting Guide

This document captures the critical issues and solutions found during the setup of the QuickHaul production and development environments.

## 1. ArgoCD Internal Communication Errors
### Issue: `i/o timeout` between Controller and Redis/Repo-Server
**Symptoms:** 
- ArgoCD dashboard shows "OutOfSync" or "Unknown".
- Logs show timeouts connecting to `argocd-redis` or `argocd-repo-server`.
**Cause:** 
- Inter-node networking failure (CNI/Weave issue) preventing pods on different nodes from communicating.
**Solution:**
- **Co-location:** Force critical ArgoCD components onto the same node as the `application-controller`.
```bash
# Example: Move Redis to the controller node
kubectl patch deployment argocd-redis -n argocd -p '{"spec": {"template": {"spec": {"nodeName": "ip-172-31-32-69"}}}}'
```

---

## 2. Kubernetes Storage (NFS) Mount Failures
### Issue: `MountVolume.SetUp failed ... exit status 32`
**Symptoms:** 
- Pods stuck in `ContainerCreating`.
- Events show `mount failed: exit status 32`.
**Solution Checklist:**
1. **Tooling:** Install `nfs-common` on ALL worker nodes:
   `sudo apt-get install nfs-common -y`
2. **Networking:** Open **Port 2049 (NFS)** in the Master Node's AWS Security Group.
3. **Configuration:** Ensure `global-values.yaml` points to the correct Master Node IP:
   `nfsServer: "172.31.41.176"`
4. **Lifecycle:** If a PV is stuck in `Terminating`, force delete it:
   `kubectl patch pv <pv-name> -p '{"metadata":{"finalizers":null}}' --type=merge`

---

## 3. Invalid Image Names (Case Sensitivity)
### Issue: `InvalidImageName` or `ImagePullBackOff`
**Symptoms:** 
- Pods fail to start with name validation errors.
**Cause:** 
- Kubernetes requires all container image names to be **lowercase**, even if the GitHub Organization name (GHCR) has uppercase letters.
**Solution:**
- Update `global-values.yaml` to use lowercase paths:
  `ghcr.io/quickhaultransits/...` (instead of `QuickHaulTransits`)
- Ensure changes are pushed to both `develop` and `main` branches.

---

## 4. ArgoCD Sync Freeze
### Issue: ArgoCD doesn't see new GitHub commits
**Symptoms:** 
- `git log` shows a new hash, but `kubectl get app` shows an old one.
**Solution:**
- Restart the Repo Server to clear its local git cache:
  `kubectl rollout restart deployment argocd-repo-server -n argocd`
- Perform a "Hard Refresh" in the UI or via CLI.

---

## 5. Missing Production Resources
### Issue: Prod apps show as "Missing" in ArgoCD
**Cause:** 
- Missing Custom Resource Definitions (CRDs) for Argo Rollouts.
**Solution:**
- Install the Rollout controller:
  `kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml`
