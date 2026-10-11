# Terraform AWS Case Study

A Terraform-based AWS infrastructure project demonstrating EC2 web-server deployment, reusable networking and compute modules, remote state management, configuration drift detection, and GitHub Actions automation.

## Project Overview

The project provisions a public Nginx web server on an EC2 instance inside a custom VPC. Terraform manages the networking and compute resources, while remote state supports collaboration and state locking.

The project also includes environment-specific configuration, infrastructure validation, security scanning, cost estimation, and a reviewed deployment workflow.

## Current Status

### Completed and verified

* [x] AWS development infrastructure deployed successfully.
* [x] Custom VPC, public subnet, internet gateway, and associated routing configured.
* [x] Reusable Terraform networking and compute modules used for the deployment.
* [x] EC2 instance provisioned and Nginx installed.
* [x] Public website verified successfully using HTTP.
* [x] Terraform remote state stored in the configured S3 bucket.
* [x] S3 state bucket confirmed to contain the Terraform state object.
* [x] S3 state bucket versioning and server-side encryption checked.
* [x] DynamoDB lock table confirmed to be `ACTIVE`.
* [x] Terraform plan confirmed no changes after the deployment was completed.
* [x] Configuration drift detection demonstrated by manually changing a VPC Name tag in AWS.
* [x] VPC Name tag restored to its configured value, followed by a Terraform plan showing no changes.

### Implemented in the repository; verification still required

The following capabilities are described in the configuration or documentation but should not be considered fully verified until their corresponding tests have been completed.

* [ ] Verify all seven original resource address migrations using the `moved` blocks.
* [ ] Run Terraform formatting, validation, and automated tests from a clean checkout.
* [ ] Verify S3-native state locking if the project is intended to use `use_lockfile`. The previously used backend configuration uses the legacy DynamoDB locking setting.
* [ ] Demonstrate Terraform-driven drift remediation. The VPC tag was restored manually through AWS CLI; automated repair has not yet been demonstrated.
* [ ] Resolve the AMI-selection difference that caused Terraform to propose replacing the existing EC2 instance during the drift demonstration.
* [ ] Verify the GitHub Actions validation, Trivy scanning, and optional Infracost workflows.
* [ ] Verify AWS OIDC authentication, IAM permissions, GitHub environment restrictions, and human approval before deployment.
* [ ] Update `VALIDATION.md` with actual test results and supporting evidence.

## Architecture

The deployed development environment contains:

* **Networking:** Custom VPC, public subnet, internet gateway, and routing.
* **Compute:** EC2 instance running Nginx.
* **Security:** Security group controlling inbound access; no inbound SSH is intended.
* **State management:** S3 remote state with the currently configured DynamoDB locking mechanism.
* **Automation:** Terraform configuration and GitHub Actions workflows for validation and reviewed deployments.

The repository also documents dev, staging, and prod environment configurations. Each environment must be validated separately before it is treated as operational.

## Prerequisites

* Terraform 1.10 or later.
* AWS CLI configured with appropriate permissions.
* An AWS account with permission to create the required resources.
* An existing private S3 bucket with versioning, encryption, public-access blocking, and appropriate access policies.
* Git and a GitHub repository for collaboration.

AWS credentials must be configured outside the repository. Do not commit access keys, secret credentials, Terraform state, or sensitive plan artifacts.

## Local Setup and Deployment

From the project directory:

```bash
cp backend.hcl.example backend.hcl
```

Edit `backend.hcl` with your actual S3 bucket name and region. Keep the real backend configuration out of version control.

Initialize Terraform:

```bash
terraform init -backend-config=backend.hcl
terraform workspace select -or-create dev
```

Format and validate the configuration:

```bash
terraform fmt -check -recursive
terraform validate
```

Create and inspect a saved plan:

```bash
terraform plan \
  -var-file=environments/dev.tfvars \
  -out=reviewed.tfplan

terraform show reviewed.tfplan
```

Apply only after reviewing the plan:

```bash
terraform apply reviewed.tfplan
terraform output web_url
```

Wait for cloud-init to finish before accessing the website. Public IP addresses may change after an instance stop/start.

**Important:** Workspaces separate Terraform state but share AWS credentials and backend infrastructure. They are not an account-level security boundary. Staging and production configurations should not be deployed without reviewing their planned resource changes and costs.

## Remote State and Locking

The development environment uses an S3 backend for remote Terraform state.

Verified so far:

* The configured S3 bucket exists.
* The Terraform state object exists.
* Bucket versioning and encryption have been checked.
* The DynamoDB lock table exists and is `ACTIVE`.

Still to verify:

* Concurrent Terraform operations are correctly prevented from modifying the same state simultaneously.
* The existing DynamoDB lock-table item is understood and does not represent an unresolved operation.
* The team agrees whether to retain DynamoDB locking or migrate to S3-native locking.

The current configuration used during deployment specifies `dynamodb_table`. This is the legacy DynamoDB locking method. S3-native locking uses `use_lockfile`. Do not change the backend without backing up state, coordinating with the team, and following a reviewed migration procedure.

## Configuration Drift

### Completed

A manual change to the VPC Name tag was introduced using AWS CLI. Terraform detected the difference between the actual tag and the declared configuration. The tag was then manually restored, and a subsequent Terraform plan reported no changes.

### Remaining

* [ ] Perform a drift test in an isolated or disposable environment.
* [ ] Introduce a small, reversible configuration change.
* [ ] Capture the Terraform plan showing the detected drift.
* [ ] Review the entire plan for unintended replacement or destruction.
* [ ] Apply a reviewed Terraform plan to restore the declared configuration.
* [ ] Run a final plan and capture evidence that the drift has been resolved.

A previous drift plan proposed replacing the running EC2 instance because the selected AMI differed from the deployed instance's AMI. **Do not apply that saved plan.** Stabilize and review the AMI configuration before attempting Terraform-driven remediation.

There is no scheduled automatic drift-remediation process verified in this revision.

## GitHub Actions and Deployment Controls

The repository documents workflows for pull-request validation and manually triggered deployments.

Remaining verification:

* [ ] Confirm pull requests run Terraform formatting and validation checks.
* [ ] Confirm the Trivy scan runs and review its findings.
* [ ] Confirm Infracost estimates are generated when correctly configured.
* [ ] Verify that the manual deployment workflow generates a saved plan.
* [ ] Verify that the plan is reviewed before approval and that the same saved plan is applied.
* [ ] Configure and verify GitHub environments and required reviewers.
* [ ] Verify AWS OIDC trust conditions and least-privilege IAM permissions.
* [ ] Confirm AWS credentials are not exposed to untrusted pull-request code.

The workflow configuration alone does not prove that AWS authentication, environment protection, or deployment approval works. These require testing in the actual GitHub repository and AWS account.

## Validation Checklist

Run the following from a clean checkout:

```bash
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
terraform test
```

Then:

* [ ] Record the Terraform version and the results of each command.
* [ ] Resolve any reproducible validation or test failures.
* [ ] Verify the GitHub Actions workflows.
* [ ] Record any checks that could not be completed and explain why.
* [ ] Update `VALIDATION.md` with results and supporting evidence.

If no Terraform tests are defined, document that fact rather than reporting the test suite as passing.

## Cleanup

Review the destruction plan before removing an environment:

```bash
terraform workspace select dev

terraform plan \
  -destroy \
  -var-file=environments/dev.tfvars \
  -out=destroy.tfplan

terraform show destroy.tfplan
terraform apply destroy.tfplan
```

Repeat for other deployed workspaces only when intended.

Destroying application infrastructure does not automatically remove the separately managed S3 backend bucket, its object versions, or a legacy DynamoDB lock table. Retain state until it is no longer required, and verify AWS resources and continuing charges after cleanup.

## Teammate Handover

The next contributor should prioritize:

1. **State locking:** Verify the actual locking mechanism and test concurrent-operation protection safely.
2. **Drift remediation:** Demonstrate a safe Terraform-driven repair in a disposable environment.
3. **Terraform validation:** Run formatting, validation, and tests; record results in `VALIDATION.md`.
4. **CI/CD:** Verify GitHub Actions, AWS OIDC, saved-plan review, and approval controls.
5. **Documentation:** Add evidence, document limitations, and submit fixes through a separate branch and pull request.

Do not replace the working EC2 instance, destroy the development stack, delete state data, or change backend settings without reviewing the impact and coordinating with the team.

## Project Limitations

This is a public HTTP demonstration, not a production-ready web architecture. It does not currently establish that TLS, a load balancer, VPC flow logs, scheduled drift remediation, or production-grade isolation have been implemented and verified.

AWS costs may include EC2, EBS, public IPv4 addresses, and resources deployed in additional workspaces. Actual costs and Free Tier eligibility depend on the account and usage.

## Final Status

The development infrastructure is deployed, the Nginx website is reachable, remote state is configured, and drift detection has been demonstrated. The remaining work is to verify locking, safely demonstrate Terraform-driven drift remediation, validate automated tests and CI/CD, and document the results in `VALIDATION.md`.
