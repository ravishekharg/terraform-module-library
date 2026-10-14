# rds-postgres

PostgreSQL on RDS with production defaults: Multi-AZ, encrypted, private, TLS forced, password kept by RDS in Secrets Manager.

## Usage
```hcl
module "db" {
  source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/rds-postgres?ref=rds-postgres/v1.0.0"

  identifier             = "orders-prod"
  subnet_ids             = module.vpc.database_subnet_ids
  vpc_security_group_ids = [module.db_sg.id]
}
```

## Design decisions
- **No password in Terraform**: `manage_master_user_password` makes RDS generate it and keep it in Secrets Manager. It never lands in state or in a variable. Apps read the secret (`master_user_secret_arn`).
- **Deletes are hard**: deletion protection on, a final snapshot always taken, automated backups kept after delete, and backups can't be turned off (`backup_retention_days` 1-35).
- **TLS forced** (`rds.force_ssl = 1`) and IAM database authentication enabled; slow-query logging over 1 s.
- **Parameter group family derived from the version** (`17` → `postgres17`) with `create_before_destroy`, so a major upgrade swaps the group cleanly. Major upgrades still need `allow_major_version_upgrade` set deliberately.
- Storage autoscaling up to `max_allocated_storage`, Performance Insights and Enhanced Monitoring on.

## Tests
`terraform test` in this directory runs `tests/*.tftest.hcl` with the AWS provider mocked: no
account or credentials needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9 |
| aws | >= 5.70, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.70, < 7.0 |

## Resources

| Name | Type |
|------|------|
| [aws_db_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_iam_role.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| identifier | DB instance identifier: lowercase letters, digits and hyphens, starting with a letter. | `string` | n/a | yes |
| subnet\_ids | Database subnets in at least two AZs. | `list(string)` | n/a | yes |
| vpc\_security\_group\_ids | Security groups for the instance (allow 5432 from the app tier only). | `list(string)` | n/a | yes |
| allocated\_storage | Initial storage in GiB. | `number` | `20` | no |
| apply\_immediately | Apply changes now instead of in the maintenance window. | `bool` | `false` | no |
| backup\_retention\_days | Automated backup retention (point-in-time restore window), 1 to 35 days. | `number` | `7` | no |
| backup\_window | Daily backup window (UTC). | `string` | `"02:00-03:00"` | no |
| db\_name | Initial database name. | `string` | `"app"` | no |
| deletion\_protection | Refuse deletes until this is turned off first. | `bool` | `true` | no |
| engine\_version | PostgreSQL version: major ("17") follows the latest minor; "17.4" pins it. | `string` | `"17"` | no |
| instance\_class | DB instance class. | `string` | `"db.t4g.micro"` | no |
| kms\_key\_arn | KMS key for storage and Performance Insights. Null uses the AWS-managed RDS key. | `string` | `null` | no |
| maintenance\_window | Weekly maintenance window (UTC); must not overlap the backup window. | `string` | `"sun:04:00-sun:05:00"` | no |
| max\_allocated\_storage | Storage autoscaling ceiling in GiB. Equal to allocated\_storage disables autoscaling. | `number` | `100` | no |
| monitoring\_interval | Enhanced Monitoring interval in seconds (0 disables). | `number` | `60` | no |
| multi\_az | Synchronous standby in a second AZ with automatic failover. | `bool` | `true` | no |
| parameters | Extra DB parameters (name => value), merged over the module's defaults. | `map(string)` | `{}` | no |
| performance\_insights | Enable Performance Insights. | `bool` | `true` | no |
| tags | Tags on every resource. | `map(string)` | `{}` | no |
| username | Master user name. The password is generated and kept in Secrets Manager by RDS; it never appears in Terraform state. | `string` | `"app_admin"` | no |

## Outputs

| Name | Description |
|------|-------------|
| address | Hostname to connect to. |
| arn | DB instance ARN. |
| db\_name | Initial database name. |
| id | DB instance identifier. |
| master\_user\_secret\_arn | Secrets Manager secret holding the master credentials (give the app read access to this, not the password). |
| port | Port to connect to. |
<!-- END_TF_DOCS -->
