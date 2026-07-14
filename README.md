# aws-infra — OIDC deployment guardrails (Terraform)

This repo provisions **all AWS resources** for the "OIDC is not enough" demo, via
a **GitHub Actions Terraform pipeline** (you never run `terraform apply` on your
laptop). It creates:

- a **GitHub OIDC identity provider** in AWS IAM,
- two **deploy roles** (`oidc-demo-staging-deploy`, `oidc-demo-production-deploy`)
  whose **trust policies** only accept the exact app repo + GitHub environment,
- least-privilege **permission policies** (staging can push to ECR + update the
  staging service; production can only update the production service and
  **cannot push** images),
- an **ECR** repository, an **ECS Fargate** cluster with **two services**
  (staging, production), each with its own task roles and logs,
- a purpose-built **VPC** (public + private subnets across 2 AZs, Internet
  Gateway, NAT Gateway) and one **Application Load Balancer per environment**.
  Fargate tasks run in the **private** subnets and are reachable only through
  the ALB.

> The companion **`sample-app`** repo holds the application and the keyless
> deploy pipeline that assumes these roles.

## Network architecture

```
                        Internet
                           │
              ┌────────────┴────────────┐
              ▼                          ▼
   ALB: oidc-demo-staging      ALB: oidc-demo-production   (public subnets, 2 AZs)
              │  :80 → :8080             │  :80 → :8080
              ▼                          ▼
   ECS task (private subnet)   ECS task (private subnet)   (no public IP)
              │                          │
              └──────────► NAT Gateway ──┴──► Internet     (egress: ECR pull, logs)
```

- **Public subnets** host the ALBs and the NAT Gateway; they route to the
  Internet Gateway.
- **Private subnets** host the Fargate tasks (no public IP). Inbound comes only
  from the ALB; outbound (image pull, CloudWatch logs) goes via the NAT Gateway.
- Each ALB listens on port 80 and forwards to the container's port 8080, health
  checking `/health`.

## Folder structure

```
aws-infra/
├── main.tf              # root: wires modules together, one ECS cluster
├── providers.tf         # AWS provider + default tags
├── versions.tf          # TF/provider versions + S3 backend (native locking)
├── variables.tf         # root inputs (github_owner, region, ...)
├── outputs.tf           # values you copy into the sample-app repo
├── terraform.tfvars.example
├── modules/
│   ├── github-oidc/     # the IAM OIDC provider
│   ├── ecr/             # image registry
│   ├── network/         # VPC, public/private subnets, IGW, NAT, route tables
│   ├── alb/             # ALB + target group + listener + SG (used x2)
│   ├── ecs-service/     # task def + service + task roles + task SG + logs (used x2)
│   └── deploy-role/     # OIDC deploy role: trust + permissions (used x2)
└── .github/workflows/terraform.yml   # init/validate/plan (auto) + apply (manual)
```

The reusable modules (`alb`, `ecs-service`, `deploy-role`) are instantiated
**twice** — once for staging, once for production. Staging vs production differ
**only** by module inputs (`github_environment`, `can_push_ecr`, names). That
difference is the entire security lesson.

## The bootstrap chicken-and-egg (read this first)

Terraform itself **creates** the OIDC provider — so on the first run the pipeline
can't use OIDC yet. And GitHub runners are ephemeral, so state can't live on
disk. Therefore:

1. You create an **S3 bucket** for Terraform state (once, in the browser).
2. The Terraform pipeline authenticates with **AWS access keys** (GitHub secrets)
   — this is the admin/bootstrap path.
3. After apply, the OIDC provider + roles exist, and the **app** pipeline is
   fully keyless.

Using keys here is not a contradiction — it's the one place a key is
unavoidable, it lives only in this admin repo, and it's gated behind manual
approval. Call this out in your article; it's a point in your favour.

## One-time setup

### 1. Create the S3 state bucket (browser, no local tools)

Open **AWS Console → CloudShell** (terminal icon, top bar) and run — pick a
globally-unique name:

```bash
BUCKET="oidc-demo-tfstate-$(date +%s)"
aws s3api create-bucket --bucket "$BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
echo "STATE BUCKET = $BUCKET"
```

Save that bucket name. (For regions other than `us-east-1`, add
`--create-bucket-configuration LocationConstraint=<region>`.)

### 2. Create an IAM user for the pipeline (browser)

Console → IAM → Users → create a user (e.g. `terraform-ci`), attach
`AdministratorAccess` (demo simplicity; tighten later), create an **access key**
of type "Application running outside AWS", and copy the key id + secret.

> This key can create IAM roles/ECS/ECR, so treat it like a password. It stays
> only in this repo's secrets and never appears in the app repo.

### 3. Configure this repo (GitHub → Settings → Secrets and variables → Actions)

**Secrets:**

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | from step 2 |
| `AWS_SECRET_ACCESS_KEY` | from step 2 |

**Variables:**

| Variable | Example |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `GH_OWNER` | your GitHub username/org, e.g. `devopswithjunaid` |
| `APP_REPO_NAME` | `sample-app` |
| `TF_STATE_BUCKET` | the bucket from step 1 |

### 4. Create the approval gate (GitHub → Settings → Environments)

Create an environment named **`production`** and add **yourself as a required
reviewer**. This is what makes `terraform apply` pause for manual approval.

## Running it

1. Push this repo to GitHub `main` (commands are in the root project README).
2. The **terraform** workflow runs automatically: `fmt` → `init` → `validate` →
   `plan`. Open the run and read the plan.
3. The **apply** job waits on the `production` environment. Click **Review
   deployments → Approve**. Terraform applies and prints outputs.
4. Copy these outputs into the `sample-app` repo as **Variables**:

| Terraform output | sample-app variable |
|---|---|
| `aws_region` | `AWS_REGION` |
| `ecr_repository_url` | `ECR_REPOSITORY_URL` |
| `ecs_cluster_name` | `ECS_CLUSTER_NAME` |
| `staging_service_name` | `STAGING_SERVICE_NAME` |
| `production_service_name` | `PRODUCTION_SERVICE_NAME` |
| `staging_task_family` | `STAGING_TASK_FAMILY` |
| `production_task_family` | `PRODUCTION_TASK_FAMILY` |
| `staging_deploy_role_arn` | `STAGING_ROLE_ARN` |
| `production_deploy_role_arn` | `PRODUCTION_ROLE_ARN` |

You can also copy the two ALB DNS names from the outputs — `curl http://<dns>/`
reaches each environment once the app is deployed.

> **Expected on first apply:** before the first `sample-app` deploy, both
> services run a **placeholder image** (nginx on port 80) that intentionally does
> **not** pass the target group health check (which probes port 8080 `/health`).
> ECS will show the tasks as unhealthy/cycling and the ALB returns `503`. This is
> normal — the infrastructure is correct and simply waiting for its first real
> application deployment, which listens on 8080 and passes `/health`.

## Tearing it down (avoid ongoing charges)

Actions tab → **terraform** workflow → **Run workflow** → choose **destroy** →
approve. The NAT Gateway and ALBs bill hourly, so destroy when you're not
demoing.

## Cost note

This is a production-style layout, so it is **not** free while running:
- **NAT Gateway** ~\$0.045/hr (~\$32/mo) + data processing
- **2 × Application Load Balancer** ~\$0.0225/hr each (~\$16/mo each)
- 2 × Fargate tasks (smallest size) + a few cents of ECR/logs

Expect a few dollars per day while up. **Destroy when you're done demoing.** A
single NAT Gateway (not one per AZ) is used deliberately to keep cost down — a
documented trade-off vs. full multi-AZ HA.

## Known simplifications (deliberate, not oversights)

These are conscious demo trade-offs; each has a clear production upgrade path:

| Simplification | Production upgrade |
|---|---|
| ALB listens on **HTTP :80** only | Add an ACM certificate + HTTPS :443 listener, redirect 80→443 |
| **Single** NAT Gateway | One NAT per AZ for high availability |
| Bootstrap uses an **AdministratorAccess** IAM user | A least-privilege Terraform role, or OIDC bootstrap |
| One Terraform **state for both environments** | Split state per environment (separate backends/workspaces) |
| Container Insights **disabled** | Enable for metrics/observability |
| ECR pulls egress via **NAT** | VPC endpoints (ecr.api, ecr.dkr, s3, logs) to drop NAT cost |
