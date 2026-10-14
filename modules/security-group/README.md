# security-group

Security group whose rules are separate resources keyed by name, with a guard against opening admin ports to the internet.

## Usage
```hcl
module "app_sg" {
  source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/security-group?ref=security-group/v1.0.0"

  name        = "orders-app"
  description = "App servers"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = [
    { name = "http-from-lb", description = "8080 from the LB", from_port = 8080, to_port = 8080, referenced_security_group_id = module.lb_sg.id },
  ]
}
```

## Design decisions
- **One resource per rule** (`aws_vpc_security_group_ingress_rule`), not inline blocks: adding a rule doesn't rewrite the others, and each rule has its own ID and tags.
- **Rules keyed by `name`**, not list position or source. Reordering the list changes nothing, and a source that is only known after apply (another module's group ID) doesn't break `for_each`.
- **Validation**: exactly one source per rule; `0.0.0.0/0` only on single TCP ports in `internet_facing_ports` (80 and 443 by default), so SSH, RDP or database ports can't be opened to the internet by mistake.
- `create_before_destroy`, so renaming a group doesn't fail on "group in use".

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
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| description | What the group is for (shown in the console; changing it replaces the group). | `string` | n/a | yes |
| name | Security group name. | `string` | n/a | yes |
| vpc\_id | VPC the group belongs to. | `string` | n/a | yes |
| egress\_rules | Egress rules, same shape as ingress\_rules. Default: all outbound traffic. | ```list(object({ name = string description = string ip_protocol = optional(string, "tcp") from_port = optional(number) to_port = optional(number) cidr_ipv4 = optional(string) referenced_security_group_id = optional(string) prefix_list_id = optional(string) }))``` | ```[ { "cidr_ipv4": "0.0.0.0/0", "description": "All outbound traffic", "ip_protocol": "-1", "name": "all" } ]``` | no |
| ingress\_rules | Ingress rules. Each rule has a stable `name` (the key in state: reordering the list changes nothing) and exactly one source: cidr\_ipv4, referenced\_security\_group\_id or prefix\_list\_id. ip\_protocol "-1" means all traffic and takes no ports. | ```list(object({ name = string description = string ip_protocol = optional(string, "tcp") from_port = optional(number) to_port = optional(number) cidr_ipv4 = optional(string) referenced_security_group_id = optional(string) prefix_list_id = optional(string) }))``` | `[]` | no |
| internet\_facing\_ports | TCP ports that may be opened to 0.0.0.0/0. | `list(number)` | ```[ 80, 443 ]``` | no |
| tags | Tags on every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| arn | Security group ARN. |
| id | Security group ID. |
| name | Security group name. |
<!-- END_TF_DOCS -->
