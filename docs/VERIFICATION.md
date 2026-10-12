# Verification on the existing AWS account

These are operator steps, not completed test results. Use a coordinated maintenance window, the correct AWS profile, and an isolated/disposable environment for drift injection. Do not upload keys, raw state, decrypted plans, or full logs to the public repository.

## 1. Read the current deployment before changing anything

In PowerShell, from your initialized deployment folder:

```powershell
$env:AWS_PROFILE = "terraform-project"
aws sts get-caller-identity
terraform workspace show
terraform state list
```

Keep the workspace actually used by the existing deployment. The original `devops/terraform.tfstate` belongs to `default`; a `dev` workspace normally uses `env:/dev/devops/terraform.tfstate`. Verify the real key/workspace instead of assuming that a README label means the workspace is `dev`. The workflow now supports `default` and refuses to create an absent workspace.

Make a private backup before any backend migration:

```powershell
New-Item -ItemType Directory -Force verification-results | Out-Null
terraform state pull | Set-Content -Encoding utf8 verification-results/before.tfstate
```

## 2. Stabilize the AMI and confirm the migrations

```powershell
python scripts/pin_deployed_ami.py
```

Use `py` instead of `python` if that is your Windows Python launcher. The helper reads state and creates ignored `deployment.auto.tfvars`; it never changes AWS or remote state. It refuses empty/ambiguous state or an existing local settings file. If another explicit tfvars file specifies `ami_id`, that value takes precedence; inspect those files too.

The latest AMI is no longer selected by default. For a deliberate NEW demo only, use `-var=allow_latest_ami=true`, then pin its AMI immediately after deployment. A pinned AMI may no longer be launchable; verify it in AWS before any deliberate rebuild.

Check `terraform state list` against these seven destination addresses:

```text
module.networking.aws_vpc.app_vpc
module.networking.aws_subnet.public_subnet
module.networking.aws_internet_gateway.igw
module.networking.aws_route_table.public_rt
module.networking.aws_route_table_association.rta
module.compute.aws_security_group.web_sg
module.compute.aws_instance.web_server
```

Tests confirm the seven unique code mappings. Only a real state listing and reviewed plan verify the deployed mappings. If original addresses remain, the moved blocks handle them during the next reviewed apply; do not delete, import, or manually move state just to make the listing match.

```powershell
terraform plan "-var-file=environments/default.tfvars" "-out=baseline.tfplan"
terraform show -json baseline.tfplan | Set-Content -Encoding utf8 baseline.plan.json
python scripts/check_plan.py baseline.plan.json
terraform show baseline.tfplan
```

Substitute the actual workspace's variable file. Require a no-change baseline before injecting drift. The helper rejects deletion/replacement but still allows creation and normal in-place changes outside tag-only mode; the entire plan needs human review. Do not apply an old plan from the repository or a previous experiment. `plan-output.txt` was removed because its mixed encoding and proposed VPC replacement made it unsafe as current evidence.

## 3. Test locking without changing infrastructure

Keep the existing backend settings for this test. In terminal A:

```powershell
terraform console
```

Leave its `>` prompt open. The console holds the state lock. In terminal B, with the same profile, directory, backend and workspace:

```powershell
terraform plan "-var-file=environments/default.tfvars" "-lock-timeout=5s"
```

Expected: an error acquiring the state lock, not an access-denied error or an unrelated plan failure. In terminal A type `exit`. Repeat the plan in B; it should succeed. Record both results and the backend mode used. Stop if a lock already exists before your test. Coordinate with its owner; never delete a DynamoDB item or force-unlock a live operation. A DynamoDB checksum item whose key ends with `-md5` is not itself an active operation lock.

To prove S3-native locking separately, coordinate all clients and back up state first. Keep bucket, key and workspace unchanged. Enable both `use_lockfile=true` and `dynamodb_table="terraform-locks"` during migration, reinitialize, and repeat the test. While console is open, confirm the corresponding `.tflock` object exists; after normal exit, confirm it is removed. For default this is `devops/terraform.tfstate.tflock`; non-default workspaces use their actual prefixed key. Once every client uses native locking, remove only the DynamoDB argument and repeat the contention test. Do not destroy the table or change the state key as part of this procedure.

S3 requires Get/Put/Delete on the `.tflock` object, but Delete is not needed on the state object. Dual mode also needs the legacy table permissions. Record which modes were actually tested; existence of a bucket/table is not proof of concurrency protection.

## 4. Demonstrate Terraform tag repair

Only after the baseline has no changes, and only on the agreed disposable VPC:

```powershell
$vpcId = terraform output -raw vpc_id
aws ec2 create-tags --region ap-south-1 --resources $vpcId --tags Key=Name,Value=temporary-drift-demo
terraform plan "-var-file=environments/default.tfvars" "-out=repair.tfplan"
terraform show -json repair.tfplan | Set-Content -Encoding utf8 repair.plan.json
python scripts/check_plan.py repair.plan.json --tag-only module.networking.aws_vpc.app_vpc
terraform show repair.tfplan
```

Expected: exactly one VPC tag update, no create/delete/replacement or changes to other resources. If the guard fails, stop and resolve the baseline; do not target only the VPC to hide other changes. After reviewing the full successful plan:

```powershell
terraform apply repair.tfplan
terraform plan "-var-file=environments/default.tfvars" -detailed-exitcode
$LASTEXITCODE
```

Expected final exit code `0`; `2` means changes remain and `1` means an error. Preserve sanitized before/repair/after summaries privately. Repair must be done by Terraform, not by restoring the tag manually and claiming auto-repair. This is reviewed remediation, not scheduled self-healing.

## 5. Configure GitHub OIDC and approvals

Set up two GitHub environments for each verified workspace, e.g. `default-plan` and `default`. Restrict both to `main`; add a human required reviewer to the apply environment, prevent self-review, and disallow bypass where available. Confirm protection is supported and enforced before setting `DEPLOYMENT_ENABLED=true`. A YAML environment name does not configure reviewers.

For each environment set these variables (plan and apply must point to the same state/workspace/AMI):

| Variable | Value |
| --- | --- |
| AWS_ROLE_ARN | Separate plan/read role or apply/write role ARN |
| AWS_REGION | Actual infrastructure/backend region, e.g. ap-south-1 |
| AWS_AMI_ID | AMI read from the deployed instance/state |
| TF_STATE_BUCKET | Existing state bucket |
| TF_STATE_KEY | Existing base state key, e.g. devops/terraform.tfstate |
| TF_LOCK_MODE | `dynamodb`, `dual`, or `s3`, matching the coordinated client configuration |
| TF_LOCK_TABLE | Existing table for dynamodb/dual modes |
| DEPLOYMENT_ENABLED | `true` only after the controls are configured |

Set the SAME high-entropy `TF_PLAN_PASSPHRASE` secret in the plan and apply environments. Share it with the reviewer securely outside the repository. The public repository receives only an encrypted plan artifact, not plaintext state/plan values. Terraform's console logs may still include nonsensitive infrastructure identifiers; never put secret material in tags or outputs.

Create the IAM OIDC provider for `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`. Each role trust must constrain the exact repository and environment, e.g. `repo:Ved05nara/terraform-case-study:environment:default-plan` for planning and `repo:Ved05nara/terraform-case-study:environment:default` for applying. No repository or environment wildcard. Use AWS/GitHub's official OIDC instructions linked below.

Plan role: relevant EC2 describe APIs plus S3 state reads/listing and lock object access (and legacy table lock APIs when applicable). Apply role additionally needs the particular networking/EC2 modification APIs and state writes. Scope resource/tag conditions where supported; do not grant AdministratorAccess, IAM wildcard access or permission to modify the OIDC trust. If the bucket uses a customer-managed KMS key, include the required key permissions. Confirm with the account owner that IAM restrictions support this architecture.

Dispatch **Reviewed Terraform deployment** on main with the ACTUAL workspace. Before approving apply, download the encrypted artifact and decrypt locally with GnuPG (passphrase is entered interactively, never in shell history):

```powershell
gpg --output reviewed.tfplan --decrypt reviewed.tfplan.gpg
terraform show reviewed.tfplan
```

Use Terraform 1.10.5 and initialize the matching commit to inspect the CI binary plan. Keep decoded files private. The workflow rejects deletions/replacements. Review legitimate additions and in-place changes explicitly. Approve only that run after the full plan review; apply consumes the same artifact. A stale state plan fails; start a new run and repeat review. Do not disable the guard to complete a demo. New workspaces must be intentionally initialized through a separately reviewed local provisioning process.

Record: successful OIDC role assumption, reviewed plan, pending approval, human approval, exact-plan apply result, and subsequent no-change plan. Until recorded, CD remains unverified.

## 6. CI and cost evidence

PR validation runs without AWS credentials. Trivy remains advisory: a green job means the scanner ran, not that findings are absent. Download `security-report` and review the findings. Enable repository variable `ENABLE_INFRACOST=true` and secret `INFRACOST_API_KEY` for trusted main pushes. Download `cost-estimate` and record its estimate/limitations. PRs do not receive the Infracost secret. Do not report cost estimates as verified while that optional step is skipped.

## Official references

- [S3 backend and simultaneous locking migration](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Console state locking](https://developer.hashicorp.com/terraform/cli/commands/console)
- [GitHub OIDC with AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [Terraform provider mocking](https://developer.hashicorp.com/terraform/language/tests/mocking)
