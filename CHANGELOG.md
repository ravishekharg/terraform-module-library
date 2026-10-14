# Changelog

One section per module release; `scripts/release.sh` refuses to tag a version without one.
Versions follow [semantic versioning](README.md#versioning).

## vpc 1.0.0
- VPC across 2-4 AZs with public, private and isolated database subnets on a fixed subnet plan.
- NAT modes `none`, `single`, `per_az`; one private route table per AZ.
- Default security group locked down; flow logs to CloudWatch Logs on by default.

## security-group 1.0.0
- Rules as separate resources keyed by name; one source per rule.
- `0.0.0.0/0` allowed only on single TCP ports listed in `internet_facing_ports`.

## ec2-asg 1.0.0
- Launch template with IMDSv2, encrypted gp3, no public IPs; Session Manager role.
- Auto Scaling group with rolling instance refresh and CPU target tracking.

## rds-postgres 1.0.0
- Multi-AZ, encrypted, private PostgreSQL; password managed by RDS in Secrets Manager.
- TLS forced, IAM auth, deletion protection, final snapshot, storage autoscaling.

## s3-bucket 1.0.0
- Private (public access blocks, no ACLs), TLS-only policy, SSE-S3 or SSE-KMS.
- Versioning with lifecycle (expire noncurrent, abort incomplete uploads, optional Standard-IA).
