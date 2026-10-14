variable "name" {
  description = "Security group name."
  type        = string
}

variable "description" {
  description = "What the group is for (shown in the console; changing it replaces the group)."
  type        = string
}

variable "vpc_id" {
  description = "VPC the group belongs to."
  type        = string
}

variable "ingress_rules" {
  description = <<-EOT
    Ingress rules. Each rule has a stable `name` (the key in state: reordering the list changes
    nothing) and exactly one source: cidr_ipv4, referenced_security_group_id or prefix_list_id.
    ip_protocol "-1" means all traffic and takes no ports.
  EOT
  type = list(object({
    name                         = string
    description                  = string
    ip_protocol                  = optional(string, "tcp")
    from_port                    = optional(number)
    to_port                      = optional(number)
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
  }))
  default = []

  validation {
    condition     = length(distinct([for r in var.ingress_rules : r.name])) == length(var.ingress_rules)
    error_message = "Ingress rule names must be unique."
  }
  validation {
    condition     = alltrue([for r in var.ingress_rules : length(compact([r.cidr_ipv4, r.referenced_security_group_id, r.prefix_list_id])) == 1])
    error_message = "Each ingress rule needs exactly one source: cidr_ipv4, referenced_security_group_id or prefix_list_id."
  }
  validation {
    condition = alltrue([for r in var.ingress_rules :
      r.cidr_ipv4 != "0.0.0.0/0" || (r.ip_protocol == "tcp" && r.from_port == r.to_port && contains(var.internet_facing_ports, coalesce(r.from_port, -1)))
    ])
    error_message = "0.0.0.0/0 is only allowed on single TCP ports listed in internet_facing_ports (default 80 and 443). Open SSH/RDP/database ports to a VPN or bastion range instead."
  }
}

variable "egress_rules" {
  description = "Egress rules, same shape as ingress_rules. Default: all outbound traffic."
  type = list(object({
    name                         = string
    description                  = string
    ip_protocol                  = optional(string, "tcp")
    from_port                    = optional(number)
    to_port                      = optional(number)
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
    prefix_list_id               = optional(string)
  }))
  default = [{ name = "all", description = "All outbound traffic", ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }]

  validation {
    condition     = length(distinct([for r in var.egress_rules : r.name])) == length(var.egress_rules)
    error_message = "Egress rule names must be unique."
  }
  validation {
    condition     = alltrue([for r in var.egress_rules : length(compact([r.cidr_ipv4, r.referenced_security_group_id, r.prefix_list_id])) == 1])
    error_message = "Each egress rule needs exactly one destination: cidr_ipv4, referenced_security_group_id or prefix_list_id."
  }
}

variable "internet_facing_ports" {
  description = "TCP ports that may be opened to 0.0.0.0/0."
  type        = list(number)
  default     = [80, 443]
}

variable "tags" {
  description = "Tags on every resource."
  type        = map(string)
  default     = {}
}
