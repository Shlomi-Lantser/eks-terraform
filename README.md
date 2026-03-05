# eks-terraform

Terraform code for provisioning the Hello World on EKS infrastructure.

## What this creates

| Resource | Details |
|---|---|
| VPC | 3 AZs, public + private subnets, single NAT gateway |
| EKS Cluster | Kubernetes 1.33, managed node group (t3.medium × 2) |
| AWS LB Controller | Installed via Helm; creates the ALB from Ingress resources |
| ECR Repository | `hello-world` image repository |
| GitHub Actions OIDC | Keyless IAM role for CI/CD pushes to ECR |
| IRSA Role | IAM role for the LB Controller (IRSA, not Pod Identity) |

## Module versions

| Module | Version |
|---|---|
| `terraform-aws-modules/vpc/aws` | `6.6.0` |
| `terraform-aws-modules/eks/aws` | `~> 21.0` |
| AWS LB Controller Helm chart | `1.13.0` |

## Prerequisites

- Terraform >= 1.5.7
- AWS CLI v2, configured with credentials (`aws configure` or env vars)
- `kubectl`
- `helm` (optional — Terraform manages Helm releases, but useful for debugging)

## First-time setup

### 1. Download the LBC IAM policy

```bash
bash bootstrap/download-lbc-policy.sh
```

This downloads the official AWS Load Balancer Controller IAM policy JSON into `lbc-iam-policy.json` (referenced by `irsa.tf`).

### 2. (Optional) Create remote state backend

Skip this if you want to use local state for the assignment.

```bash
AWS_REGION=us-east-1 bash bootstrap/create-tf-backend.sh
```

Then uncomment the `backend "s3"` block in `versions.tf` and fill in the bucket name.

### 3. Update `ecr.tf`

In `ecr.tf`, replace `YOUR_GITHUB_ORG/YOUR_APP_REPO` with your actual GitHub org and repo name:

```hcl
"token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_ORG/hello-world-app:*"
```

### 4. Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

Terraform will output everything you need, including the `configure_kubectl` command.

### 5. Configure kubectl

```bash
# The exact command is in the terraform output:
aws eks update-kubeconfig --region us-east-1 --name hello-world-dev-cluster

# Verify:
kubectl get nodes
```

## Key outputs

| Output | Description |
|---|---|
| `configure_kubectl` | Copy-paste command to configure kubectl |
| `ecr_repository_url` | Use this in your CI/CD pipeline to push images |
| `github_actions_role_arn` | Paste into your GitHub Actions workflow as `role-to-assume` |
| `cluster_name` | EKS cluster name |
| `cluster_region` | AWS region |

## How to get the public URL

After ArgoCD deploys the app and the Ingress is created, run:

```bash
kubectl get ingress -n hello-world
```

The `ADDRESS` column will show the ALB DNS name (e.g. `k8s-xxxx.us-east-1.elb.amazonaws.com`).
It takes ~2 minutes for the ALB to become active after first creation.

## Destroy

```bash
# Important: delete any Ingress resources first so the LB Controller can clean up the ALB
kubectl delete ingress --all -n hello-world

# Wait ~1 minute, then destroy
terraform destroy
```

> **Why?** The ALB is created by the LB Controller in response to Ingress resources — it is NOT
> tracked in Terraform state. If you destroy Terraform first, the ALB will be orphaned in AWS
> and you'll need to delete it manually.

## Architecture

```
Internet
   │
   ▼
AWS ALB  (created by AWS LB Controller from Ingress annotations)
   │
   ▼
EKS Cluster  (private subnets, us-east-1a/b/c)
   │
   ▼
hello-world Pod  (managed by ArgoCD)
```
