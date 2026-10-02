# Automated Cloud Infrastructure Provisioning & Drift Remediation with Terraform

A DevOps case study demonstrating Infrastructure as Code (IaC) principles: automated provisioning, enterprise remote state management, concurrency locking, and configuration drift self-healing on AWS.

---

## Overview

This project replaces manual cloud administration with declarative code using HashiCorp Terraform. It establishes an automated workflow to deploy, audit, and reconcile cloud networking and compute resources reproducibly.

---

## What Has Been Done

- **Declarative Cloud Architecture (`main.tf`, `variables.tf`, `providers.tf`):**
  - Custom Virtual Private Cloud (VPC) with a dedicated CIDR block (`10.0.0.0/16`).
  - Public subnet mapped with auto-assign public IPv4 addressing.
  - Internet Gateway (IGW) and custom Route Table for external routing.
  - Security Group enforcing ingress rules (Port 80 for HTTP and Port 22 for SSH) and unrestricted egress.
  - Automated Ubuntu EC2 instance bootstrap via `user_data` installing and starting an Nginx web server.

- **Enterprise Remote State & Concurrency Locking (`backend.tf`):**
  - Migrated local state to an Amazon S3 bucket with versioning enabled for state durability and audit history.
  - Integrated an Amazon DynamoDB table (`LockID` partition key) to enforce distributed state locking, preventing race conditions during concurrent runs.

- **Configuration Drift Detection & Self-Healing:**
  - Injected out-of-band drift by manually deleting ingress firewall rules directly in the AWS Console.
  - Used `terraform plan` to query live cloud state, identify configuration drift, and calculate an execution delta.
  - Applied targeted remediation via `terraform apply` to restore the declared state in place without disrupting running compute instances.

- **Clean De-provisioning:**
  - Automated full-stack teardown via `terraform destroy`, ensuring zero orphaned cloud resources or ongoing billing.

---

## Tech Stack & Tools

- **IaC Engine:** Terraform (HCL)
- **Cloud Provider:** Amazon Web Services (AWS Free Tier)
- **Services Utilized:** EC2, VPC, Internet Gateway, Subnets, Route Tables, Security Groups, S3, DynamoDB
- **Web Engine:** Nginx on Ubuntu Linux
- **VCS:** Git & GitHub

---

## Next Steps / Future Enhancements

1. **Automated CI/CD Workflows (GitHub Actions):**
   - Implement pipeline workflows to run `terraform fmt -check`, `terraform validate`, and automated `terraform plan` generation on pull requests.
   - Configure gated manual approvals for `terraform apply` on main branch merges.

2. **Shift-Left Security & Static Analysis (DevSecOps):**
   - Integrate static analysis tools such as **Tfsec** or **Trivy** to catch open security groups and compliance misconfigurations prior to deployment.
   - Run **Infracost** within the pipeline to predict monthly AWS expenditure deltas on proposed infrastructure changes.

3. **Code Modularization:**
   - Decompose monolithic configurations into reusable Terraform modules (e.g., `modules/networking` and `modules/compute`).
   - Introduce environment isolation workspaces (`dev`, `staging`, `prod`) driven by independent `.tfvars` definitions.
