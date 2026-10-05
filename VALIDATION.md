# Validation handover

Checks completed locally:
- Terraform 1.10.5 recursive formatting and format check: passed.
- Both GitHub Actions files parsed as YAML: passed (syntax only).
- Nginx user-data script checked with `bash -n`: passed.
- Provider/module initialization initially completed with AWS 5.100.0.

Full Terraform validation was blocked: initial provider schema startup failed, and subsequent validation reported a cached-provider checksum mismatch. The committed lockfile retains provider checksums; checks were not bypassed. Run initialization and validation from a clean checkout on your machine or GitHub runner. Do not copy local `.terraform` caches.

A mocked Terraform plan test checks IMDSv2, root-volume encryption, and the HTTP-only ingress count. It is included in CI but was not executable locally because of the provider issue. Run:

```bash
terraform init -backend=false
terraform validate
terraform test
```

Not executed: Trivy scan, Infracost estimate, GitHub Actions jobs, real AWS plan/apply/destroy, live Nginx smoke test, or drift restoration. These need external services and account configuration. No AWS resources were created or modified during this work.
