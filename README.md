# terraform-module-library

Reusable Terraform modules for the core of an AWS workload: network, security groups, compute,
PostgreSQL and object storage. Each module ships safe defaults, input validation that rejects
risky settings, tests, generated docs, and its own version tags.

```
examples/web-app ──uses──> modules/vpc ──────────── VPC, 3 tiers of subnets, NAT, flow logs
                           modules/security-group ─ rules as resources, no admin ports to 0.0.0.0/0
                           modules/ec2-asg ──────── launch template + Auto Scaling group, IMDSv2, SSM
                           modules/rds-postgres ─── Multi-AZ PostgreSQL, password in Secrets Manager
                           modules/s3-bucket ────── private, TLS-only, encrypted, versioned
```

It's a personal project built for interviews, not code from a former employer.

| Module | What it gives you by default | Docs |
|---|---|---|
| `vpc` | 2-4 AZs; public, private and isolated database subnets on a fixed plan; NAT per AZ (or single/none); default SG with no rules; flow logs | [README](modules/vpc/README.md) |
| `security-group` | One resource per rule, keyed by name; exactly one source per rule; `0.0.0.0/0` only on 80/443 | [README](modules/security-group/README.md) |
| `ec2-asg` | IMDSv2 only, encrypted gp3, no public IP, Session Manager instead of SSH, rolling instance refresh, CPU target tracking | [README](modules/ec2-asg/README.md) |
| `rds-postgres` | Multi-AZ, encrypted, private, TLS forced, IAM auth, deletion protection, final snapshot, password generated and kept by RDS | [README](modules/rds-postgres/README.md) |
| `s3-bucket` | Public access blocked, ACLs off, deny non-TLS, SSE-S3/KMS, versioning, lifecycle | [README](modules/s3-bucket/README.md) |

[`examples/web-app`](examples/web-app) composes all five into a three-tier app, with prod-only
choices (per-AZ NAT, Multi-AZ, deletion protection) driven by one `env` variable.

## Using a module
Pin a released version of each module separately:
```hcl
module "vpc" {
  source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/vpc?ref=vpc/v1.0.0"

  name = "orders-prod"
  cidr = "10.30.0.0/16"
}
```

## Versioning
Each module is versioned on its own with tags `<module>/v<MAJOR.MINOR.PATCH>`, so a fix to
`s3-bucket` doesn't force every VPC consumer to review an upgrade.

| Change | Version bump |
|---|---|
| Removing or renaming a variable or output; a new required variable; a default that changes behaviour or **replaces existing resources**; a higher minimum Terraform/provider version | **MAJOR** |
| New optional variable or output, new optional resource that is off by default | MINOR |
| Fix with no interface or plan change for existing users | PATCH |

`scripts/release.sh <module> <version>` tags a release only if the version is valid and newer than
the module's last tag, `CHANGELOG.md` has an entry for it, and the module's tests pass.

## Testing
| Layer | What | Where | Result |
|---|---|---|---|
| Offline tests | `terraform test` with the AWS provider **mocked**: plans every module with default and edge-case inputs, asserts on the planned resources, and checks that validations reject bad input | `modules/*/tests`, `examples/web-app/tests` | **40 / 40 runs pass** (vpc 10, security-group 7, ec2-asg 6, rds-postgres 8, s3-bucket 7, example 2) |
| Integration | Real apply against **LocalStack**, then reads resources back through the AWS API (database tier has no default route, private route tables go through NAT, app group admits only the LB group, bucket policy denies non-TLS), then destroy | `tests/localstack` | **Passing** (vpc, security-group, s3-bucket) |
| Lint | tflint, preset `all` + AWS ruleset | `.tflint.hcl` | Clean |
| Security | Checkov | inline `checkov:skip` with reasons | **116 passed, 0 failed**, 7 skips (5 distinct, each with its reason) |
| Docs | terraform-docs tables in each module README must match the code | `.terraform-docs.yml` | Checked in CI |

**What isn't tested for real:** `ec2-asg` and `rds-postgres` need Auto Scaling and RDS, which
LocalStack's free edition doesn't have, and nothing here has been applied to a real AWS account
(no bill). Their behaviour is covered by the plan-level tests only. Before production use, the
next step is a short-lived apply in a sandbox account from CI (OIDC role, `terraform test` with
`command = apply`, then destroy).

## Run it
```bash
# offline, no AWS account
for d in modules/* examples/web-app; do (cd $d && terraform init -backend=false && terraform test); done

# integration
docker run -d -p 4566:4566 localstack/localstack:4.4
cd tests/localstack && terraform init && terraform test
```
Needs Terraform 1.9+ (tests were run with 1.15.6). CI runs all of it on every push
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)).
