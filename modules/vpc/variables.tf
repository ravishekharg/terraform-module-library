variable "name" {
  description = "Name prefix for every resource."
  type        = string
}

variable "cidr" {
  description = "IPv4 CIDR of the VPC, /16 to /24."
  type        = string
  validation {
    condition     = can(cidrhost(var.cidr, 0)) && can(regex("/(1[6-9]|2[0-4])$", var.cidr))
    error_message = "cidr must be a valid IPv4 CIDR with a prefix between /16 and /24."
  }
}

variable "azs" {
  description = "Availability Zones to use. Null picks the first az_count zones of the region."
  type        = list(string)
  default     = null
  validation {
    condition     = var.azs == null || try(length(var.azs) >= 2 && length(var.azs) <= 4, false)
    error_message = "Use 2 to 4 Availability Zones."
  }
}

variable "az_count" {
  description = "How many Availability Zones to spread over when azs is null."
  type        = number
  default     = 3
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 4
    error_message = "az_count must be between 2 and 4: one AZ is not highly available, and the subnet plan reserves room for 4."
  }
}

variable "subnet_newbits" {
  description = "Bits added to the VPC prefix for each subnet (4 on a /16 gives /20 subnets). Subnet index per tier: public 0-3, private 4-7, database 8-11."
  type        = number
  default     = 4
  validation {
    condition     = var.subnet_newbits >= 4 && tonumber(split("/", var.cidr)[1]) + var.subnet_newbits <= 28
    error_message = "subnet_newbits must be at least 4 (room for 12 subnets) and leave subnets no smaller than /28."
  }
}

variable "nat_gateway_mode" {
  description = "none (no internet egress from private subnets), single (one NAT: cheaper, but its AZ is a dependency for all) or per_az (one NAT per AZ: production)."
  type        = string
  default     = "per_az"
  validation {
    condition     = contains(["none", "single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be none, single or per_az."
  }
}

variable "create_database_subnets" {
  description = "Create an isolated database tier with no route to the internet."
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs (all traffic) to CloudWatch Logs."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention of the flow log group, in days."
  type        = number
  default     = 365
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a value CloudWatch Logs accepts (1, 3, 5, 7, 14, 30, ... 3653)."
  }
}

variable "flow_log_kms_key_arn" {
  description = "KMS key that encrypts the flow log group. Null uses CloudWatch Logs' default encryption."
  type        = string
  default     = null
}

variable "public_subnet_tags" {
  description = "Extra tags on public subnets (e.g. kubernetes.io/role/elb = 1)."
  type        = map(string)
  default     = {}
}

variable "private_subnet_tags" {
  description = "Extra tags on private subnets (e.g. kubernetes.io/role/internal-elb = 1)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags on every resource."
  type        = map(string)
  default     = {}
}
