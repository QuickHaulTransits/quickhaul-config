# 🛠️ QuickHaul CD Troubleshooting Guide

This document captures the real-world issues encountered during the implementation of the QuickHaul CD pipeline and the solutions applied.

---

## 1. Issue: `ImagePullBackOff` (403 Forbidden)
**Symptoms**: Pods fail to start, `kubectl describe` shows "403 Forbidden" when pulling from `ghcr.io`.
**Root Cause**: GitHub Container Registry (GHCR) packages were set to private, and the Kubernetes cluster lacked credentials to pull them.
**Solution**:
1.  Created a `docker-registry` secret named `regcred` in both `quickhaul-dev` and `quickhaul-prod` namespaces using a GitHub PAT.
2.  Updated `global-values.yaml` to include `imagePullSecrets`.
3.  Standardized all Helm templates to include the `imagePullSecrets` block in the Pod specification.

---

## 2. Issue: `ModuleNotFoundError: No module named 'services'`
**Symptoms**: Pods enter `CrashLoopBackOff`, and logs show Python failing to find the `services` module.
**Root Cause**: The Docker image structure copied code to the root (`/app`), but the Helm charts were prefixing the `uvicorn` command with `services.[service_name].`.
**Solution**: Updated the `command` in all `deployment.yaml` templates to point directly to the module at the root (e.g., `main:app` or `app:app`).

---

## 3. Issue: MongoDB PV stuck in `Released` status
**Symptoms**: MongoDB PVC stays `Pending`, and the PV shows status `Released`.
**Root Cause**: The PV had a `Retain` reclaim policy and was still "bound" to a deleted namespace/claim reference.
**Solution**: Patched the PV to clear the `claimRef`, making it `Available` for the new namespace:
```bash
kubectl patch pv mongodb-nfs-pv -p '{"spec":{"claimRef":null}}'
```

---

## 4. Issue: Storage Collision between Dev and Prod
**Symptoms**: Potential data corruption or lock errors when both environments are running.
**Root Cause**: Both Dev and Prod were sharing the exact same NFS path (`/mnt/nfs/mongodb`).
**Solution**:
1.  Created separate directories on the NFS server: `/mnt/nfs/mongodb-dev` and `/mnt/nfs/mongodb-prod`.
2.  Updated `nfs-pv.yaml` to use dynamic naming based on `{{ .Values.global.environment }}`.
3.  Mapped `dev` and `prod` environment variables in the respective `values.yaml` files.

---

## 5. Issue: Hardcoded Namespaces in Templates
**Symptoms**: Resources being created in the wrong namespace (e.g., `quick-haul`) regardless of ArgoCD settings.
**Root Cause**: Many Helm templates had `namespace: quick-haul` hardcoded in their metadata.
**Solution**: Standardized all templates to use `namespace: {{ .Release.Namespace }}`, ensuring they follow the destination defined in the ArgoCD Application manifest.

---

## 6. Issue: NFS Server Connection Failure
**Symptoms**: MongoDB pods stuck in `ContainerCreating` or `Pending`.
**Root Cause**: The original NFS instance was down, and the IP in `global-values.yaml` was stale.
**Solution**: Provisioned a new NFS EC2 instance, configured `nfs-kernel-server`, and updated the `nfsServer` IP in the global configuration repo.
