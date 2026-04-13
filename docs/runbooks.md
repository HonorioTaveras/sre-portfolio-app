# SRE Portfolio -- Runbooks and Resilience Demonstrations

## Scenario 1: Terraform Drift Detection

### What it demonstrates
Infrastructure drift occurs when someone manually changes AWS resources outside of Terraform.
Terraform detects this by comparing live AWS state against the desired state in code.

### Steps to reproduce

```bash
# 1. Apply infrastructure
terragrunt apply

# 2. Manually add a tag to an ECR repository in the AWS console
# Go to ECR > dev-sre-portfolio-api > Tags > Add tag: manually-added=true

# 3. Run plan -- Terraform detects the unauthorized change
terragrunt plan

# 4. Apply -- Terraform reconciles the drift
terragrunt apply
```

### Expected plan output

```
~ tags = {
    "Name" = "dev-sre-portfolio-api"
  - "manually-added" = "true" -> null
}
Plan: 0 to add, 1 to change, 0 to destroy.
```

### Why it matters
In production, engineers sometimes make emergency changes directly in the console.
Drift detection ensures these changes are caught and either codified or reverted.
The professional rule: if Terraform owns a resource, only Terraform changes it.

---

## Scenario 2: Kubernetes and ArgoCD Self-Healing

### What it demonstrates
Two layers of self-healing working together:
- Layer 1: Kubernetes Deployment controller replaces crashed pods automatically
- Layer 2: ArgoCD detects configuration drift and restores desired state from Git

### Kubernetes self-healing

```bash
# Watch pods in real time
kubectl get pods -n sre-portfolio -w

# In another terminal -- delete a pod
kubectl delete pod -n sre-portfolio -l app=sre-portfolio-api

# Expected: Kubernetes replaces the pod within ~14 seconds
# Service never interrupts -- Deployment controller acts immediately
```

### ArgoCD self-healing

```bash
# Scale deployment to 0 -- simulates someone bypassing GitOps
kubectl scale deployment sre-portfolio-api --replicas=0 -n sre-portfolio

# Expected: ArgoCD detects drift within ~4 minutes
# ArgoCD restores replicas=1 from Git automatically
# No human intervention required
```

### Zero-downtime rolling update

```bash
# Deploy a bad image tag
kubectl set image deployment/sre-portfolio-api \
  api=sre-portfolio-api:broken \
  -n sre-portfolio

# Expected: new pod fails with ErrImageNeverPull
# Old pod stays Running -- service never interrupted
# Verify: curl http://localhost:8080/health returns 200 throughout

# Rollback
kubectl set image deployment/sre-portfolio-api \
  api=sre-portfolio-api:latest \
  -n sre-portfolio
```

### Why it matters
- Kubernetes self-healing: pod failures recover in seconds with no human intervention
- ArgoCD self-healing: configuration drift is automatically reverted -- Git is always the source of truth
- Zero-downtime: maxUnavailable=0 ensures traffic never drops during a bad deploy

---

## Scenario 3: Chaos Engineering -- Database Failure

### What it demonstrates
System behavior during a database pod failure and automatic recovery.

### Steps to reproduce

```bash
# Tab 1 -- continuous health monitoring
while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
  echo "$(date '+%H:%M:%S') -- /health returned $STATUS"
  sleep 1
done

# Tab 2 -- delete the Postgres pod
kubectl delete pod -n sre-portfolio -l app=sre-portfolio-postgres

# Tab 3 -- attempt to create a job during the outage
curl -s -X POST http://localhost:8080/jobs \
  -H "Content-Type: application/json" \
  -d '{"task": "chaos_test"}'
```

### Expected behavior

```
# Health endpoint stays 200 throughout
13:33:01 -- /health returned 200
13:33:02 -- /health returned 200
13:33:03 -- /health returned 200

# Job creation returns 500 during outage -- graceful degradation
{"detail":"relation \"jobs\" does not exist..."}

# After API restart -- full recovery
{"job_id":1,"status":"queued"}
```

### Recovery steps

```bash
# Restart API to trigger table recreation via SQLAlchemy create_all()
kubectl rollout restart deployment/sre-portfolio-api -n sre-portfolio

# Restart port-forward after pod replacement
kubectl port-forward svc/sre-portfolio-api -n sre-portfolio 8080:80
```

### Key observations
- Health checks must never depend on downstream services -- they reflect only process health
- Stateful applications need PersistentVolumeClaims for data to survive pod restarts
- Graceful degradation means the system fails in a controlled, informative way rather than crashing silently
- Full recovery achieved within ~2 minutes with no manual data intervention

### Why it matters
Database failures are one of the most common production incidents.
This demonstrates that the system handles them gracefully without cascading failures
and recovers automatically once the dependency is restored.
