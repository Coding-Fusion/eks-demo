# Phase 3 — Cluster-per-Environment Pipeline (the Walmart model)

```
git push → Source → Build → Deploy-Dev (dev-cluster) → Approval → Deploy-QA (qa-cluster)
```

- ONE deploy buildspec; pipeline injects ENV + EKS_CLUSTER per stage
- Namespace "inventory" is the same in every cluster (team/app separation,
  Walmart-style) — environments are separated by CLUSTER
- Same image tag promoted dev → qa (build once, deploy many)

💰 COST: two clusters ≈ $0.42/hr (~$10/day). Create both, do the exercise,
delete both the same day.

---

## Step 0 — Create the two clusters (~15 min each; run in parallel terminals)

```bash
eksctl create cluster --name dev-cluster --region us-east-1 \
  --nodes 1 --node-type t3.small --managed

eksctl create cluster --name qa-cluster --region us-east-1 \
  --nodes 1 --node-type t3.small --managed
```

(1 node each is enough for this app.)

Your kubeconfig now has BOTH clusters as "contexts". Switch between them:

```bash
kubectl config get-contexts                 # list; * marks current
kubectl config use-context <name-with-dev-cluster>
kubectl get nodes                           # you're looking at dev
kubectl config use-context <name-with-qa-cluster>
kubectl get nodes                           # now qa
```

## Step 1 — Push this project to GitHub (if not already)

```bash
git init && git add . && git commit -m "cluster-per-env pipeline"
git remote add origin https://github.com/<you>/eks-demo.git
git branch -M main && git push -u origin main
```

If the repo already exists from before: just commit + push the changed files.

## Step 2 — Two CodeBuild projects (as before)

- eks-demo-build  → buildspec-build.yml,  ✅ Privileged, env var ACCOUNT_ID
- eks-demo-deploy → buildspec-deploy.yml, Privileged OFF, env var ACCOUNT_ID

## Step 3 — Permissions

Build role:  attach AmazonEC2ContainerRegistryPowerUser
Deploy role: inline policy eks:DescribeCluster on *

RBAC bridge — NOW NEEDED ON BOTH CLUSTERS (each cluster has its own RBAC!):

```bash
DEPLOY_ROLE_ARN=<copy from IAM console>

eksctl create iamidentitymapping --cluster dev-cluster --region us-east-1 \
  --arn $DEPLOY_ROLE_ARN --group system:masters --username codebuild-deploy

eksctl create iamidentitymapping --cluster qa-cluster --region us-east-1 \
  --arn $DEPLOY_ROLE_ARN --group system:masters --username codebuild-deploy
```

## Step 4 — Pipeline

CodePipeline → Create pipeline "eks-demo-pipeline":
1. Source: GitHub App → repo, branch main
2. Build: CodeBuild → eks-demo-build
3. Skip deploy stage; after creation EDIT pipeline and add:
   - Stage "Deploy-Dev": CodeBuild action → eks-demo-deploy
     Input artifact: BuildArtifact
     Env vars: ENV=dev, EKS_CLUSTER=dev-cluster
   - Stage "Approve": Manual approval
   - Stage "Deploy-QA": CodeBuild action → eks-demo-deploy
     Input artifact: BuildArtifact
     Env vars: ENV=qa, EKS_CLUSTER=qa-cluster

## Step 5 — Run

```bash
git commit --allow-empty -m "trigger" && git push
```

Build → Deploy-Dev green → verify dev:

```bash
kubectl config use-context <dev-context>
kubectl get pods -n inventory
kubectl get svc -n inventory        # curl dev EXTERNAL-IP
```

Approve in console → Deploy-QA → verify qa the same way (switch context).
Same image tag in both clusters — check the "version" field in the JSON.

## Teardown (both!)

```bash
eksctl delete cluster --name dev-cluster --region us-east-1
eksctl delete cluster --name qa-cluster --region us-east-1
```

## Adding Prod later = pure repetition:
create prod-cluster → RBAC-map the deploy role → add Deploy-Prod stage with
ENV=prod, EKS_CLUSTER=prod-cluster. Nothing else changes. That's the payoff
of the parameterized design.
