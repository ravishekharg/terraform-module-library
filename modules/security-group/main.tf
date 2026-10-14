locals {
  tags = merge(var.tags, { "managed-by" = "terraform", "module" = "security-group" })
}

resource "aws_security_group" "this" {
  # checkov:skip=CKV2_AWS_5: the module creates the group; the caller attaches it to instances, ENIs or load balancers
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id
  tags        = merge(local.tags, { Name = var.name })

  # A replacement (new name or description) creates the new group before deleting the old one,
  # so instances can be moved over instead of failing on a group that is still in use.
  lifecycle {
    create_before_destroy = true
  }
}

# One resource per rule (not inline blocks): rules can be added or removed without touching others,
# and each rule gets its own ID and tags. Keyed by name, so list order doesn't matter.
resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for r in var.ingress_rules : r.name => r }

  security_group_id            = aws_security_group.this.id
  description                  = each.value.description
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port                      = each.value.ip_protocol == "-1" ? null : each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
  prefix_list_id               = each.value.prefix_list_id
  tags                         = merge(local.tags, { Name = "${var.name}-in-${each.key}" })
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for r in var.egress_rules : r.name => r }

  security_group_id            = aws_security_group.this.id
  description                  = each.value.description
  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port                      = each.value.ip_protocol == "-1" ? null : each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
  prefix_list_id               = each.value.prefix_list_id
  tags                         = merge(local.tags, { Name = "${var.name}-out-${each.key}" })
}
