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
- a security group on the **default VPC** (no ALB, no NAT — near-zero idle cost).

> The companion **`sample-app`** repo holds the application and the keyless
> deploy pipeline that assumes these roles.

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
│   ├── network/         # default-VPC lookups + security group
│   ├── ecs-service/     # task def + service + task roles + logs (used x2)
│   └── deploy-role/     # OIDC deploy role: trust + permissions (used x2)
└── .github/workflows/terraform.yml   # init/validate/plan (auto) + apply (manual)
```

The reusable modules (`ecs-service`, `deploy-role`) are instantiated **twice** —
once for staging, once for production. Staging vs production differ **only** by
module inputs (`github_environment`, `can_push_ecr`, names). That difference is
the entire security lesson.

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

> After apply but before the first app deploy, both ECS services run a harmless
> **placeholder image** (nginx) and are **not** reachable on the app port yet.
> That's expected — the first `sample-app` deploy replaces it with your image.

## Tearing it down (avoid ongoing charges)

Actions tab → **terraform** workflow → **Run workflow** → choose **destroy** →
approve. Fargate tasks cost money while running, so destroy (or scale services to
0) when you're not demoing.

## Cost note

Default-VPC + public-IP Fargate with **no ALB and no NAT** keeps idle cost
essentially to the two running Fargate tasks (smallest size) + a few cents of
ECR/logs. Destroy when done.
