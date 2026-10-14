# vpc

VPC across 2-4 Availability Zones with public, private and isolated database subnets.

## Usage
```hcl
module "vpc" {
  source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/vpc?ref=vpc/v1.0.0"

  name             = "orders-prod"
  cidr             = "10.30.0.0/16"
  az_count         = 3
  nat_gateway_mode = "per_az"
}
```

## Design decisions
- **Fixed subnet plan.** Subnet index per tier: public 0-3, private 4-7, database 8-11 (`cidrsubnet(cidr, newbits, i)`). Adding an AZ later never renumbers existing subnets, so nothing is replaced.
- **Three NAT modes.** `per_az` (production: an AZ outage only takes that AZ's egress), `single` (one NAT for dev: about a third of the cost, one AZ becomes a dependency), `none`.
- **One private route table per AZ**, so per-AZ NAT keeps traffic inside its AZ (no cross-AZ data charges).
- **Isolated database tier**: its route table has only the local route (checked against LocalStack in `tests/localstack`).
- **Default security group taken over with no rules**, public subnets don't hand out public IPs, flow logs on by default (1 year).

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
| [aws_cloudwatch_log_group.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.private_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route.public_internet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cidr | IPv4 CIDR of the VPC, /16 to /24. | `string` | n/a | yes |
| name | Name prefix for every resource. | `string` | n/a | yes |
| az\_count | How many Availability Zones to spread over when azs is null. | `number` | `3` | no |
| azs | Availability Zones to use. Null picks the first az\_count zones of the region. | `list(string)` | `null` | no |
| create\_database\_subnets | Create an isolated database tier with no route to the internet. | `bool` | `true` | no |
| enable\_flow\_logs | Send VPC flow logs (all traffic) to CloudWatch Logs. | `bool` | `true` | no |
| flow\_log\_kms\_key\_arn | KMS key that encrypts the flow log group. Null uses CloudWatch Logs' default encryption. | `string` | `null` | no |
| flow\_log\_retention\_days | Retention of the flow log group, in days. | `number` | `365` | no |
| nat\_gateway\_mode | none (no internet egress from private subnets), single (one NAT: cheaper, but its AZ is a dependency for all) or per\_az (one NAT per AZ: production). | `string` | `"per_az"` | no |
| private\_subnet\_tags | Extra tags on private subnets (e.g. kubernetes.io/role/internal-elb = 1). | `map(string)` | `{}` | no |
| public\_subnet\_tags | Extra tags on public subnets (e.g. kubernetes.io/role/elb = 1). | `map(string)` | `{}` | no |
| subnet\_newbits | Bits added to the VPC prefix for each subnet (4 on a /16 gives /20 subnets). Subnet index per tier: public 0-3, private 4-7, database 8-11. | `number` | `4` | no |
| tags | Tags on every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| azs | Availability Zones used, in subnet order. |
| database\_subnet\_ids | Database subnet IDs, one per AZ (empty when create\_database\_subnets is false). |
| nat\_public\_ips | Public IPs of the NAT gateways (for partners that allow-list your egress). |
| private\_route\_table\_ids | Private route table IDs, one per AZ (for gateway endpoints). |
| private\_subnet\_ids | Private subnet IDs, one per AZ. |
| public\_subnet\_ids | Public subnet IDs, one per AZ. |
| vpc\_cidr | CIDR of the VPC. |
| vpc\_id | ID of the VPC. |
<!-- END_TF_DOCS -->
