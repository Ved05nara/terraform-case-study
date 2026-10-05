# Terraform AWS case study

A public Nginx demonstration on EC2 with a custom VPC, reusable networking/compute modules, remote state, drift repair, environment workspaces, and GitHub Actions.

## Completed in this revision
- Modules and moved blocks for all seven original resources.
- dev/staging/prod variable files and workspace-specific names/tags.
- Regional Canonical Ubuntu AMI discovery; optional AMI pinning.
- IMDSv2 required, encrypted gp3 root disk, no inbound SSH.
- Configurable S3 backend with native state locking.
- Pull-request format/validation checks, advisory Trivy scan, optional Infracost estimates on trusted main pushes.
- Manually dispatched deployment with a saved plan and GitHub environment approval before applying that exact plan.

## Local setup
Install Terraform 1.10+ and configure AWS credentials outside this repository. Use an existing private, versioned S3 state bucket with encryption, public-access blocking, and TLS-only policy. Bucket creation is deliberately separate from application state. Backend role needs bucket listing and state object read/write plus lock object read/write/delete; non-default workspace paths require matching permissions.

```bash
cp backend.hcl.example backend.hcl
# Edit backend.hcl with your bucket and region.
terraform init -backend-config=backend.hcl
terraform workspace select -or-create dev
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=environments/dev.tfvars -out=reviewed.tfplan
terraform show reviewed.tfplan
terraform apply reviewed.tfplan
terraform output web_url
```
Wait for cloud-init to finish, then visit the output URL. Public IPs can change on stop/start. No key pair or SSH access is provisioned. Inspect cloud-init logs through an independently configured administration method if bootstrap fails.

Workspaces separate state but share credentials and a bucket; they are not an account-level security boundary. `prod` is a separate demonstration environment, not a production-ready architecture. Each environment incurs its own costs, including EC2, EBS and public IPv4 charges. Free Tier eligibility is account-specific.

## Upgrade an existing deployment
Back up state securely (`terraform state pull`) before upgrading. Keep the original bucket, key, region and workspace. Do not switch to a new workspace expecting existing resources to move with you. During locking migration, keep `dynamodb_table` alongside `use_lockfile` until every Terraform client is upgraded. Coordinate migration with other users and do not force-unlock an active operation.

The moved blocks map original addresses into modules. They do not guarantee zero replacement: AMI discovery, security-group naming, disk settings, user data, tags and CIDRs may change resources. For the original default workspace first plan with the original CIDRs (root defaults) and set `ami_id` to the currently deployed AMI. Review all replacements before applying. `terraform init -migrate-state` is needed only when actually moving backend state; `-reconfigure` does not migrate state. Creating a new dev workspace creates another stack.

## GitHub configuration
1. Push this directory including `.github`, the provider lockfile and environment variable files.
2. Enable branch protection requiring the Terraform validation job.
3. Create GitHub environments `dev-plan`, `staging-plan`, `prod-plan`, and `dev`, `staging`, `prod`. Restrict each to main. Add required reviewers to each apply environment **before running deployment**; YAML alone does not enforce human approval. Ensure your GitHub plan supports these protections.
4. In each environment set `AWS_ROLE_ARN`, `AWS_REGION` and `TF_STATE_BUCKET`. Configure separate read/plan and write/apply IAM roles. Trust GitHub OIDC with audience `sts.amazonaws.com` and the exact repository/environment subject `repo:OWNER/REPO:environment:ENVIRONMENT`. Plan needs state/lock access, describe APIs and AMI lookup; apply additionally needs narrowly scoped provisioning permissions. No long-lived AWS secrets are needed.
5. Run **Reviewed Terraform deployment** from main and choose the environment. Review `reviewed-plan.txt`, then approve the environment job. Binary plans can contain secrets: keep the repository/artifacts private and restrict access. Stale plans fail; rerun planning rather than bypassing review.
6. Optional: set repository variable `ENABLE_INFRACOST=true` and secret `INFRACOST_API_KEY`. Main pushes generate an estimate artifact; PRs never receive the key. Estimates are advisory and do not include every usage-based charge.

PRs run without AWS credentials. Authenticated planning runs only through the manual main-branch workflow to avoid granting cloud access to PR code. Trivy is advisory (`exit-code: 0`), not a security gate: this public demo intentionally exposes HTTP and omits production controls such as TLS, load balancing and VPC flow logs. Review findings, implement required controls, then change exit-code to 1 for enforcement. Third-party actions use version tags; pin audited commit SHAs before adopting this workflow in a sensitive repository.

## Drift demonstration
In a disposable demo environment only, remove the port-80 ingress rule in AWS. Run `terraform plan -var-file=environments/dev.tfvars -out=repair.tfplan`, review the rule restoration and apply the saved plan. Capture before/after plan and HTTP evidence. Never use refresh-only apply to repair drift: it updates state rather than restoring declared infrastructure. There is no scheduled auto-remediation in this revision.

## Cleanup
```bash
terraform workspace select dev
terraform plan -destroy -var-file=environments/dev.tfvars -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```
Repeat for any other deployed workspace. Application destroy retains the separately managed state bucket, object versions and any legacy lock table; those can still have costs. Keep them until state retention is no longer needed. Confirm resource teardown in AWS rather than assuming a successful command eliminates all account charges.

## Validation and remaining account work
See `VALIDATION.md` for checks performed in the editing environment. AWS deployment, OIDC trust, bucket configuration, reviewer protection, cost estimates and live drift recovery require your account and are not claimed as tested here.
