# Validation record — 12 October 2026

Reviewed starting commit: `8dc54cac72960a3eb2f2c0c9c050b4cd4c4ce500`.

## Evidence inspected

- README on main separates verified infrastructure from pending locking, remediation, AMI and CI/CD checks.
- Latest [main CI run](https://github.com/Ved05nara/terraform-case-study/actions/runs/38122501855) failed at `terraform fmt -check -recursive`, specifically `environments/dev.tfvars`. Terraform validation/tests, Trivy and cost estimation did not run in that job.
- Existing `plan-output.txt` was an obsolete mixed-encoding plan proposing VPC replacement, not proof of successful remediation. Removed the file; raw plans and outputs are ignored going forward.

## Checks performed in a fresh checkout

| Check | Result |
| --- | --- |
| Terraform version | 1.10.5, linux_amd64 |
| `terraform init -backend=false -input=false` | Passed; AWS 5.100.0 installed with HashiCorp signature |
| `terraform fmt -check -recursive` | Passed after fixing dev.tfvars |
| Workflow YAML parsing | Passed for checks.yml and deploy.yml; syntax only |
| `bash -n` on init_backend.sh and user-data.sh | Passed |
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | Passed, 4 tests covering AMI extraction, unsafe plan rejection, all 7 unique moved mappings, and backend arguments for each locking mode |
| `git diff --check` | Passed |
| Local Terraform provider validation/test execution | Blocked: provider could not open its Unix socket (`operation not permitted`) in this runtime; no checksum/security checks bypassed |

Terraform mocked tests now cover encrypted storage/IMDSv2/ingress, pinned AMI bypass of discovery, missing-AMI rejection, explicit discovery and configured network routing. The GitHub PR run must provide the independent clean-runner check. Publishing was attempted but the GitHub integration rejected branch/tree creation with HTTP 403, so no PR or new CI run was created. Apply the supplied patch and push a branch to execute these tests.

## Live account verification still pending

No live AWS credentials were used for this review. No infrastructure, backend configuration or remote state was changed. Historical success in the README is teammate-reported, not independently re-tested in this session.

- Current state listing of all seven module destinations.
- Actual deployed AMI pin and no-change baseline.
- Concurrent-operation rejection and normal lock release for the selected locking mode; native `.tflock` lifecycle if migrating.
- Tag-only Terraform-driven drift repair, followed by a no-change plan.
- AWS OIDC, scoped role permissions, protected environments, human review and exact saved-plan apply.
- Infracost estimate with an account key; it is skipped unless enabled.

Follow [docs/VERIFICATION.md](docs/VERIFICATION.md). Record sanitized dates, command exit codes and workflow URLs here after each real test. Keep credentials, raw state and decrypted plan evidence private.

The encrypted-plan round-trip is included as a credential-free CI check. Local GPG execution was also blocked in this runtime, so that check remains pending on the runner.

## GitHub verification - 12 October 2026
CI passed: https://github.com/Ved05nara/terraform-case-study/actions/runs/38249554694
Formatting, Terraform validation/tests, Python helper tests, encrypted-plan round trip, and Trivy execution passed.
This resolves the previously pending clean-runner checks. Infracost and live AWS locking, drift repair, and OIDC deployment remain unverified.

## Live verification - 12 October 2026

- Verified all seven managed resources use their module addresses.
- Pinned the deployed AMI; the baseline plan showed no changes.
- Verified S3 lock contention with dual S3/DynamoDB locking configured: a competing plan failed while an interactive apply held the lock.
- Cancelled that apply, removed the temporary test configuration, and confirmed a no-change plan.
- Changed the VPC Name tag to temporary-drift-demo.
- Terraform planned only the tag repair: 0 to add, 1 to change, 0 to destroy.
- Applied the saved repair plan; the following plan showed no changes.
- GitHub OIDC deployment and Infracost verification remain pending.
