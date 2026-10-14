mock_provider "aws" {}

variables {
  name        = "app"
  description = "app servers"
  vpc_id      = "vpc-12345678"
}

run "https_from_internet_and_app_port_from_lb" {
  command = plan
  variables {
    ingress_rules = [
      { name = "https", description = "HTTPS from anywhere", from_port = 443, to_port = 443, cidr_ipv4 = "0.0.0.0/0" },
      { name = "app-from-lb", description = "8080 from the load balancer", from_port = 8080, to_port = 8080, referenced_security_group_id = "sg-0abc" },
    ]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 2 && aws_vpc_security_group_ingress_rule.this["app-from-lb"].referenced_security_group_id == "sg-0abc"
    error_message = "two ingress rules keyed by name"
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 1 && aws_vpc_security_group_egress_rule.this["all"].ip_protocol == "-1" && aws_vpc_security_group_egress_rule.this["all"].from_port == null
    error_message = "default egress: all traffic, no ports"
  }
}

run "rejects_ssh_from_internet" {
  command = plan
  variables {
    ingress_rules = [{ name = "ssh", description = "SSH", from_port = 22, to_port = 22, cidr_ipv4 = "0.0.0.0/0" }]
  }
  expect_failures = [var.ingress_rules]
}

run "rejects_port_range_from_internet" {
  command = plan
  variables {
    ingress_rules = [{ name = "web", description = "80 to 443", from_port = 80, to_port = 443, cidr_ipv4 = "0.0.0.0/0" }]
  }
  expect_failures = [var.ingress_rules]
}

run "ssh_allowed_from_vpn_range" {
  command = plan
  variables {
    ingress_rules = [{ name = "ssh-vpn", description = "SSH from the VPN", from_port = 22, to_port = 22, cidr_ipv4 = "10.99.0.0/16" }]
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["ssh-vpn"].cidr_ipv4 == "10.99.0.0/16"
    error_message = "SSH from a private range is fine"
  }
}

run "rejects_two_sources" {
  command = plan
  variables {
    ingress_rules = [{ name = "x", description = "x", from_port = 5432, to_port = 5432, cidr_ipv4 = "10.0.0.0/8", referenced_security_group_id = "sg-0abc" }]
  }
  expect_failures = [var.ingress_rules]
}

run "rejects_duplicate_names" {
  command = plan
  variables {
    ingress_rules = [
      { name = "a", description = "a", from_port = 1, to_port = 1, cidr_ipv4 = "10.0.0.0/8" },
      { name = "a", description = "b", from_port = 2, to_port = 2, cidr_ipv4 = "10.0.0.0/8" },
    ]
  }
  expect_failures = [var.ingress_rules]
}

run "internet_facing_ports_can_be_extended" {
  command = plan
  variables {
    internet_facing_ports = [80, 443, 8443]
    ingress_rules         = [{ name = "alt-https", description = "8443", from_port = 8443, to_port = 8443, cidr_ipv4 = "0.0.0.0/0" }]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 1
    error_message = "8443 is allowed once listed"
  }
}
