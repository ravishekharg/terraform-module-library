# ec2-asg

Auto Scaling group of hardened instances from a launch template: IMDSv2, encrypted gp3, no public IPs, Session Manager instead of SSH.

## Usage
```hcl
module "app" {
  source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/ec2-asg?ref=ec2-asg/v1.0.0"

  name               = "orders-app"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.app_sg.id]
  min_size           = 2
  max_size           = 6
  desired_capacity   = 2
}
```

## Design decisions
- **IMDSv2 required, hop limit 1**: a container on the host can't fetch the instance role's credentials.
- **No SSH keys**: the role gets `AmazonSSMManagedInstanceCore`; people connect through Session Manager (audited, no open port 22).
- **Rolling instance refresh** (90% kept healthy) when the launch template changes: a new AMI or user data rolls out without downtime.
- **`desired_capacity` changes are ignored after creation**, so the scaling policy (CPU target tracking, 60% by default) and Terraform don't fight.
- Default AMI: the latest Amazon Linux 2023 from AWS's public SSM parameter; pin `ami_id` for reproducible builds.

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
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_ssm_parameter.al2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name prefix for the launch template, Auto Scaling group and IAM role. | `string` | n/a | yes |
| security\_group\_ids | Security groups for the instances. | `list(string)` | n/a | yes |
| subnet\_ids | Private subnets to launch into, ideally one per AZ. | `list(string)` | n/a | yes |
| additional\_iam\_policy\_arns | Managed policies attached to the instance role, besides SSM Session Manager access. | `list(string)` | `[]` | no |
| ami\_id | AMI to launch. Null uses the latest Amazon Linux 2023 for `architecture` (from the public SSM parameter). | `string` | `null` | no |
| architecture | x86\_64 or arm64; only used to pick the default AMI. | `string` | `"x86_64"` | no |
| cpu\_target\_percent | Target-tracking scaling on average CPU. Null disables the policy. | `number` | `60` | no |
| desired\_capacity | Instances at creation. Later changes are ignored, so scaling policies and people don't fight Terraform. | `number` | `2` | no |
| health\_check\_grace\_period | Seconds after launch before health checks count. | `number` | `300` | no |
| health\_check\_type | EC2 (instance status) or ELB (load balancer health checks: use it when target\_group\_arns is set). | `string` | `"EC2"` | no |
| instance\_type | EC2 instance type. | `string` | `"t3.micro"` | no |
| kms\_key\_arn | KMS key for the root volume. Null uses the account's default EBS key. | `string` | `null` | no |
| max\_size | Maximum number of instances. | `number` | `4` | no |
| min\_size | Minimum number of instances. | `number` | `2` | no |
| root\_volume\_size | Root volume size in GiB. | `number` | `20` | no |
| tags | Tags on every resource, propagated to instances and volumes. | `map(string)` | `{}` | no |
| target\_group\_arns | Load balancer target groups to register instances with. | `list(string)` | `[]` | no |
| user\_data | Plain-text user data (cloud-init or shell). The module base64-encodes it. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| autoscaling\_group\_arn | ARN of the Auto Scaling group. |
| autoscaling\_group\_name | Name of the Auto Scaling group. |
| iam\_role\_arn | Instance role ARN. |
| iam\_role\_name | Instance role name (attach more policies to it from outside if needed). |
| launch\_template\_id | ID of the launch template. |
<!-- END_TF_DOCS -->
